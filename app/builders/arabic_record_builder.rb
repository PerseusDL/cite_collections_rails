#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

class ArabicRecordBuilder
  require 'nokogiri'
  include ApplicationHelper

  # Built to process a file of tab separated values comprising of catalog records for Arabic works 
  # collected from catalogs across the internet. 
  # Produces MODS and MADS files for these records so that they might be incorporated into the 
  # Perseus catalog and CITE tables.

  def process_file(file)
    # file headings
    #
    # top level mods
    # 0RECORD_URI  1BOOKTITLE_URI 2BOOKTITLE_TRANSLIT  3BOOKTITLE_NAMETRUS  4BOOKTITLE_NAME_TRSIM  
    # 5BOOKTITLE_NAME_AR 6BOOKTITLE_ALT_TRANSLIT  7BOOKTITLE_ALT_NAME_TRUS 8BOOKTITLE_ALT_NAME_TRSIM  
    # 9BOOKTITLE_ALT_NAME_AR
    #
    # mads
    # 10AUTHOR_URI  11AUTHOR_DIED_AH  12AUTHOR_DIED_CE  13AUTHOR_NAME_TRANSLIT  14AUTHOR_NAME_TRUS  
    # 15AUTHOR_NAME_TRSIM 16AUTHOR_NAME_AR
    #
    # original record, host related items, these may or may not appear
    # 17REC_AUTHOR_AKA  18REC_AUTHOR_NAME 19REC_BOOK_TITLE  20REC_BOOK_TITLE_SUB  21REC_BOOK_SUBJ 
    # 22REC_BOOK_VOLS 23REC_LIB_READ_ONLINE 24REC_LIB_URL 25REC_LIB_URL_FILE  26REC_LIB_URL_VOLS  
    # 27REC_ED_ALL  28REC_ED_EDITOR 29REC_ED_NUMBER 30REC_ED_PUBLISHER  31REC_ED_PLACE  32REC_ED_YEAR 
    # 33REC_ED_ISBN 34REC_ED_PAGES  35REC_ED_PHYSICAL 
    #
    # manuscript items
    # 36REC_MS_CITY 37REC_MS_COUNTRY  38REC_MS_LIBRARY  39REC_MS_SHELF  
    #
    # notes
    # 40REC_MISC  41REC_NOTE  42REC_OTHER_AUTHORS 43REC_MISC_INFO


    File.foreach(file) do |line|
      unless line =~ /record_uri/i
        line_arr = line.split("\t")
        if file =~ /Authors/
          xml_file, urn = build_mads_record(line_arr)
          f = File.new("#{ENV['HOME']}/catalog_pending/mads/arabic/#{urn}.mads.xml", 'w')
        else
          xml_file, urn = build_mods_record(line_arr)       
          f = File.new("#{ENV['HOME']}/catalog_pending/mods/arabic/#{urn}.mods.xml", 'w')
        end
        if xml_file
          f << xml_file
          f.close
        end
      end
    end
  end

  def build_mods_record(line_arr)
    begin
      alt_titles = line_arr[3, 4]
      alt_titles = alt_titles & line_arr[6..9]
      r_name, r_date = name_and_date(line_arr[13])
      a_name, a_date = name_and_date(line_arr[16])
      mrurn = line_arr[0]
      urn = ctsurn_creation(mrurn, line_arr[1])
      

      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |new_mods|
        
        new_mods.mods('xmlns:mods' => "http://www.loc.gov/mods/v3", 
              'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
              'xmlns:atom' => "http://www.w3.org/2005/Atom",
              'xsi:schemaLocation' => "http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd"){
          new_mods.parent.namespace = new_mods.parent.namespace_definitions.find{|ns|ns.prefix=="mods"}

          #titles
          new_mods['mods'].titleInfo(:lang => 'ara', :script => "Arabic"){
            new_mods['mods'].title(line_arr[5])
          }
          new_mods['mods'].titleInfo(:lang => 'ara', :type => "uniform"){
            new_mods['mods'].title(line_arr[2])
          }
          alt_titles.each do |title|
            unless title == "nodata"
              new_mods['mods'].titleInfo(:lang => 'ara', :type => "alternative"){
                new_mods['mods'].title(title)
              }
            end
          end

          #author name(s)
          #providing both the Arabic script and the transliteration
          #putting all name parts into one field for now, could split them into part vs. term of address
          #if I can get a list of words indicating it is indeed a term of address
          #Also need to split out the dates in the Arabic script names
          new_mods['mods'].name(:type => "personal", :script => "Arabic"){
            new_mods['mods'].namePart(a_name)
            new_mods['mods'].namePart(:type => 'date'){
              new_mods.text(a_date)
            } if a_date
            new_mods['mods'].role{
              new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                new_mods.text("creator")
              }
            }
          }
          new_mods['mods'].name(:type => "personal", :usage => "primary"){
            new_mods['mods'].namePart(r_name)
            new_mods['mods'].namePart(:type => 'date'){
              new_mods.text(r_date)
            } if r_date
            new_mods['mods'].role{
              new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                new_mods.text("creator")
              }
            }
          }

          #language
          new_mods['mods'].language(:objectPart => "text"){
            new_mods['mods'].languageTerm(:type => "code", :authority => "iso639-2b"){
              new_mods.text("ara")
            }
          }

          #identifiers
          #naming Maxim's ids 'mrurn' for now, can be changed
          new_mods['mods'].identifier(:type => 'mrurn'){
            new_mods.text(mrurn)
          }
          new_mods['mods'].identifier(:type => 'ctsurn'){
            new_mods.text(urn)
          }

          #URL
          liburls = [line_arr[23], line_arr[24]]
             
          liburls.each do |liburl|
            unless liburl == "nodata"
              liburl.split("::::").each do |url|
                new_mods['mods'].location{
                  new_mods['mods'].url(:displayLabel => url_label(url)){
                    new_mods.text(url)
                  }
                }
              end
            end
          end 

          #host volume info
          new_mods['mods'].relatedItem(:type => "host"){
            
            #record title
            unless line_arr[19] == "nodata"
              title_string = line_arr[19]
              title_string << "::::#{line_arr[20]}" unless line_arr[20] == "nodata"
              title_string.split("::::").each_with_index do |title, i|
              if i == 0
                new_mods['mods'].titleInfo(:lang => 'ara'){
                  new_mods['mods'].title(line_arr[19])
                } 
              else
                new_mods['mods'].titleInfo(:type => "alternative", :lang => 'ara'){
                  new_mods['mods'].title(line_arr[19])
                } 
              end
            else
              new_mods['mods'].titleInfo(:lang => 'ara', :script => "Arabic"){
                new_mods['mods'].title(line_arr[5])
              }
            end

            #record author
            unless line_arr[17] == "nodata"
              aka_name, aka_date = name_and_date(line_arr[17])
              new_mods['mods'].name(:type => "personal"){
                new_mods['mods'].namePart(aka_name)
                new_mods['mods'].namePart(:type => 'date'){
                  new_mods.text(aka_date)
                } if aka_date
                new_mods['mods'].role{
                  new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                    new_mods.text("creator")
                  }
                }
              }
            end
            unless line_arr[18] == "nodata"
              rec_name, rec_date = name_and_date(line_arr[18])
              new_mods['mods'].name(:type => "personal"){
                new_mods['mods'].namePart(rec_name)
                new_mods['mods'].namePart(:type => 'date'){
                  new_mods.text(rec_date)
                } if rec_date
                new_mods['mods'].role{
                  new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                    new_mods.text("creator")
                  }
                }
              }
            end

            #editor(s)
            unless line_arr[28] == "nodata"
              eds = line_arr[28].split("::::")
              eds.each do |ed|
                new_mods['mods'].name(:type => "personal", :script => "Arabic"){
                  new_mods['mods'].namePart(ed)
                  new_mods['mods'].role{
                    new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                      new_mods.text("editor")
                    }
                  }
                }
              end            
            end

            #type of resource
            if mrurn =~ /MS\d+/
              new_mods['mods'].typeOfResource(:manuscript => "yes"){
                new_mods.text("text")
              }
            else
              new_mods['mods'].typeOfResource("text")
            end

            #language
            new_mods['mods'].language(:objectPart => "text"){
              new_mods['mods'].languageTerm(:type => "code", :authority => "iso639-2b"){
                new_mods.text("ara")
              }
            }

            #origin info
              unless line_arr[27] == "nodata"            
                place, publisher, year = ed_info(line_arr[27])
              else
                place = line_arr[31] == "nodata" ? "s.n." : line_arr[31] 
                publisher = line_arr[30] == "nodata" ? "s.n." : line_arr[30]
                date = line_arr[32] == "nodata" ? "s.d." : line_arr[32]
              end
              unless place == "s.n." && publisher == "s.n." && date == "s.d."
                new_mods['mods'].originInfo{
                  new_mods['mods'].place{
                    new_mods['mods'].placeTerm(:type => "text"){
                      new_mods.text(place)
                    }
                  }
                  new_mods['mods'].publisher(publisher)
                  new_mods['mods'].dateIssued(date)
                  new_mods['mods'].edition(line_arr[29]) unless line_arr[29] == "nodata"
                }
              end

            #physicalDescription
            ext = phys_desc(line_arr[22], line_arr[34], line_arr[35])
            
            new_mods['mods'].physicalDescription{
              new_mods['mods'].form("text")
              unless ext.empty?
                new_mods['mods'].extent(ext.join("; "))
              end
            }

            #notes
            line_arr[40..43].each do |note|
              unless note =~ /nodata/  #regex instead of string comp b/c last field has carriage return, fails string comp
                new_mods['mods'].note(note)
              end
            end
            
            #subject - very imperfect method, no good way to determine subfields (topic, geographic, names)
            if line_arr[21] != "nodata" || line_arr[21] != "NONE"
              line_arr[21].split(/::::|;/).each do |subj|
                new_mods['mods'].subject{
                  subj.split(/>>>|>/).each do |topic|
                    new_mods['mods'].topic(topic)
                  end
                }
              end
            end

            #identifier
            if line_arr[33] != "nodata"
              new_mods['mods'].identifier(:type => "isbn"){
                new_mods.text(line_arr[33])
              }
            end

            #location
            #URLs          
            fileurl = line_arr[25] == "nodata" ? nil : line_arr[25]
            volsurls = line_arr[26] == "nodata" ? nil : line_arr[26]
           
            if fileurl  
              fileurl.split("::::").each do |url|
                new_mods['mods'].location{
                  new_mods['mods'].url(:displayLabel => url_label(url), :access => "raw object"){
                    new_mods.text(url)
                  }
                }
              end
            end

            if volsurls
              new_mods['mods'].location(:displayLabel => "Volume urls"){
                volsurls.split("::::").each do |url|
                  new_mods['mods'].url(:displayLabel => url_label(url)){
                    new_mods.text(url)
                  }
                end
              }
            end

            #physical location (for MSs)
            unless line_arr[36] == "nodata"
              ms_arr = ms_locations(line_arr[36], line_arr[37], line_arr[38], line_arr[39])
              ms_arr.each do |cell|
                new_mods['mods'].location(:displayLabel => url_label(mrurn)){
                  new_mods['mods'].physicalLocation(cell[0])
                  new_mods['mods'].shelfLocator(cell[1])
                }
              end
            end
          }


        }
      end

      return builder.to_xml, urn
    rescue
      puts "issue with #{urn}, #{$!}"
      return nil, nil
    end
  end

  def build_mads_record(line_arr)

  end

  def ctsurn_creation(mrurn, work_mrurn)
    #Will need to change this around once the records are added to the CITE tables, then it will
    #be possible to look up the last urn in the table.
    #For now just creating a variable to carry the last assigned urn.

    cts_file = File.open("#{ENV['HOME']}/arabic_urns.txt", 'a+')
    cts_list = cts_file.read
    ms_suffix = mrurn =~ /MS\d+/ ? mrurn[/MS\d+/] : ""
    mrurnc = mrurn.sub(/\./, "")
    cts_ed = mrurnc.gsub(/#|_\d+.?\w*/, "")
    cts_ed << ms_suffix 
    unless cts_list.empty?
      unless cts_list.include?(mrurn)
        matches = cts_list.scan(/^.+#{work_mrurn}.+$/)      
        unless matches.empty?
          #author & work match, need to check library
          m_eds = matches.select{|r| r =~ /#{cts_ed}/}
          unless m_eds.empty?
            #same lib
            last_cts = m_eds.last.split(',')[0]
            num = last_cts.slice!(/\d+$/).to_i
            cts = last_cts + (num + 1).to_s
          else
            #new lib edition
            cts = "cts:urn:arabicLit:#{cts_ed}-ara1"
          end
        else
          cts = "cts:urn:arabicLit:#{cts_ed}-ara1"
        end
        cts_file << "\n#{cts},#{mrurn}"
      else
        puts "This record already has a ctsurn assigned"
        cts = cts_list.scan(/^.+#{mrurn}$/).last.split(',')[0]
      end
    else
      cts = "cts:urn:arabicLit:#{cts_ed}-ara1"
      cts_file << "#{cts},#{mrurn}"  
    end
    cts_file.close
    return cts
  end


  def url_label(url_or_urn)
    label = case url_or_urn
      when /alwaraq/
        "al-Warraq"
      when /noorlib/
        "Noor Digital Library"
      when /shiaonlinelibrary/
        "Shia Online Library"
      when /hathitrust/
        "HathiTrust"
      when /\.JK_/
        "al-Jami' al-kabir"
      when /\.Khizana_/
        "Khizanat al-turath"
      when /shamela/
        "al-Maktaba al-shamila"
      when /waqfeya/
        "al-Maktaba al-waqfiyya" 
      when /worldcat/
        "WorldCat"
      when /archive\.org/
        "Open Content Alliance"        
    end
  end

  def name_and_date(full_name)
    name = full_name.split(/\(|\)/)
    if name[1] =~ /\d+/
      name_date = name.delete_at(1)
    else
      name_date = nil
    end
    return name[0], name_date
  end

  def ed_info(cell)
    #typical format == place: publisher, year
    if cell =~ /.+\:.+[,:;]/
      p1 = cell.split(":")
      place = p1[0].strip
      date = p1[1][/\[?\d+-?\s?(or|i. e.)*\s?\d*\]?\??/]
      publisher = p1[1].gsub(/#{date}|,|\.|:|;/, "").strip
    else
      if cell =~ /,|;/
        p1 = cell.split(/,|;/)
        if p1.length == 3
          place = p1[0].strip
          publisher = p1[1].strip
          date = p1[2].gsub(".", "").strip
        else
          if p1[0].length > p1[1].length
            date = p1[1].gsub(".", "").strip
            split = p1[0].split(/\] | \[/)
            place = split[0]
            place = place + "]" if place.include?("[")
            publisher = split[1]
            publisher = "[" + publisher if publisher.include?("]")
          else
            place = p1[0]
            split = p1[1].split(/\] | \[/)
            publisher = split[0]
            publisher = publisher + "]" if publisher.include?("[")
            date = split[1]
            date = "[" + date if date.include?("]")
          end
        end
      else
        #assuming just a date
        date = cell
        place = "s.n."
        publisher = "s.n."
      end
    end
    return place, publisher, date   
  end

  def phys_desc(vols, pgs, phys)
    ext = []
    ext << "#{vols} v." unless vols == "nodata"
    ext << "#{pgs} p." unless pgs == "nodata"
    ext << "phys" unless phys == "nodata"
    return ext
  end

  def ms_locations(city_raw, country_raw, lib_raw, shelf_raw)
    city = city_raw.split("::::")
    country = country_raw.split("::::")
    lib = lib_raw.split("::::")
    shelf = shelf_raw.split("::::")
    ms_arr = []
    city.each_with_index do |c, i|
      phys = "#{lib[i]} #{c} #{country[i]}"
      ms_arr[i] = [phys, shelf[i]]
    end
    return ms_arr
  end

end