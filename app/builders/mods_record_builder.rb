class ModsRecordBuilder
  require 'nokogiri'
  include ApplicationHelper

=begin
  
0"primary id",1"primary id type",2"additional ids (id|type;etc)",3"primary title",
4"other titles (title|type;etc)",5"author name",6"author term of address",7"author date(s)",
8"authority;authorityURI;valueURI",9"editor or translator",10"name",11"term of address",12"date(s)",
13"authority;authorityURI;valueURI",14"editor or translator",15"name",16"term of address",17"date(s)",
18"authority;authorityURI;valueURI",19"editor or translator",20"name",21"term of address",22"date(s)",
23"authority;authorityURI;valueURI",24"manuscript? (t/f)",25"country code",26"city",27"publisher",
28"dateIssued",29"dateCreated",30"dateModified",31"edition",32"text language code",
33"other languages (lang code|objectPart;)",34"extent desc.",35"page start",36"page end",37"page range",
38"Topics, ; separated",39"series title",40"location (label|url;etc)"
  
=end  

  def mods_builder(line_arr)
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |new_mods|
          
      new_mods.mods('xmlns:mods' => "http://www.loc.gov/mods/v3", 
            'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
            'xmlns:atom' => "http://www.w3.org/2005/Atom",
            'xsi:schemaLocation' => "http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-4.xsd"){
        new_mods.parent.namespace = new_mods.parent.namespace_definitions.find{|ns|ns.prefix=="mods"}

        #titles
        new_mods['mods'].titleInfo{
          new_mods['mods'].title(line_arr[3])
        }

        alts = line_arr[4].split(';')
        alts.each do |alt|
          parts = alt.split("|")
          new_mods['mods'].titleInfo(:type => "#{parts[1]}"){
            new_mods['mods'].title(parts[0])
          }
        end
        
        #names (could probably abstract this out, but it would complicate matters...)
        #5"author name",6"author term of address",7"author date(s)",8"authority;authorityURI;valueURI"
        authorities = line_arr[8].split(';')

        new_mods['mods'].name(:authority => "#{authorities[0]}", :authorityURI => "#{authorities[1]}", :type => "personal", :valueURI => "#{authorities[2]}"){
          new_mods['mods'].namePart(line_arr[5])
          new_mods['mods'].namePart(:type => 'termsOfAddress'){
            new_mods.text(line_arr[6])
          } if line_arr[6] != ""
          new_mods['mods'].namePart(:type => 'date'){
            new_mods.text(line_arr[7])
          } if line_arr[7] != ""
          new_mods['mods'].role{
            new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
              new_mods.text("creator")
            }
          }
        }

        #9"editor or translator",10"name",11"term of address",12"date(s)",13"authority;authorityURI;valueURI"
        unless line_arr[9] == ""
          authorities = line_arr[13].split(';')

          new_mods['mods'].name(:authority => "#{authorities[0]}", :authorityURI => "#{authorities[1]}", :type => "personal", :valueURI => "#{authorities[2]}"){
            new_mods['mods'].namePart(line_arr[10])
            new_mods['mods'].namePart(:type => 'termsOfAddress'){
              new_mods.text(line_arr[11])
            } if line_arr[11] != ""
            new_mods['mods'].namePart(:type => 'date'){
              new_mods.text(line_arr[12])
            } if line_arr[12] != ""
            new_mods['mods'].role{
              new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                new_mods.text(line_arr[9])
              }
            }
          }
        end

        #14"editor or translator",15"name",16"term of address",17"date(s)",18"authority;authorityURI;valueURI"
        unless line_arr[14] == ""
          authorities = line_arr[18].split(';')

          new_mods['mods'].name(:authority => "#{authorities[0]}", :authorityURI => "#{authorities[1]}", :type => "personal", :valueURI => "#{authorities[2]}"){
            new_mods['mods'].namePart(line_arr[15])
            new_mods['mods'].namePart(:type => 'termsOfAddress'){
              new_mods.text(line_arr[16])
            } if line_arr[16] != ""
            new_mods['mods'].namePart(:type => 'date'){
              new_mods.text(line_arr[17])
            } if line_arr[17] != ""
            new_mods['mods'].role{
              new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                new_mods.text(line_arr[14])
              }
            }
          }
        end

        #19"editor or translator",20"name",21"term of address",22"date(s)",23"authority;authorityURI;valueURI"
        unless line_arr[19] == ""
          authorities = line_arr[23].split(';')

          new_mods['mods'].name(:authority => "#{authorities[0]}", :authorityURI => "#{authorities[1]}", :type => "personal", :valueURI => "#{authorities[2]}"){
            new_mods['mods'].namePart(line_arr[20])
            new_mods['mods'].namePart(:type => 'termsOfAddress'){
              new_mods.text(line_arr[21])
            } if line_arr[21] != ""
            new_mods['mods'].namePart(:type => 'date'){
              new_mods.text(line_arr[22])
            } if line_arr[22] != ""
            new_mods['mods'].role{
              new_mods['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
                new_mods.text(line_arr[19])
              }
            }
          }
        end

        #ids
        #0"primary id",1"primary id type",2"additional ids (id|type;etc)"
        new_mods['mods'].identifier(:type => "#{line_arr[1]}"){
          new_mods.text(line_arr[0])
        }
        unless line_arr[2] == ""
          add_ids = line_arr[2].split(';')
          add_ids.each do |add_id|
            a_id = add_id.split('|')
            new_mods['mods'].identifier(:type => "#{a_id[1]}"){
              new_mods.text(a_id[0])
            }
          end
        end

        #type of resource
        if line_arr[24] == "t"
          new_mods['mods'].typeOfResource(:manuscript => "yes"){
            new_mods.text("text")
          }
        elsif line_arr[24] == "f" || line_arr[24] == ""
          new_mods['mods'].typeOfResource("text")
        end

        #25"country code",26"city",27"publisher",28"dateIssued",29"dateCreated",30"dateModified",31"edition"
        new_mods['mods'].originInfo{
          new_mods['mods'].place{
            new_mods['mods'].placeTerm(:type => "code", :authority => "marccountry"){
              new_mods.text(line_arr[25])
            } unless line_arr[25] == ""
          }
          new_mods['mods'].place{
            new_mods['mods'].placeTerm(:type => "text"){
              new_mods.text(line_arr[26])
            } unless line_arr[26] == ""
          }
          new_mods['mods'].publisher(line_arr[27]) unless line_arr[27] == ""
          new_mods['mods'].dateIssued(line_arr[28]) unless line_arr[28] == ""
          new_mods['mods'].dateCreated(line_arr[29]) unless line_arr[29] == ""
          new_mods['mods'].dateModified(line_arr[30]) unless line_arr[30] == ""
          new_mods['mods'].edition(line_arr[31]) unless line_arr[31] == ""
        }

        #language
        #32"text language code",33"other languages (lang code|objectPart;)
        new_mods['mods'].language(:objectPart => "text"){
          new_mods['mods'].languageTerm(:type => "code", :authority => "iso639-2b"){
            new_mods.text(line_arr[32])
          }
        }

        unless line_arr[33] == ""
          other_langs = line_arr[33].split(';')
          other_langs.each do |part|
            parts = part.split('|')
            new_mods['mods'].language(:objectPart => "#{parts[1]}"){
              new_mods['mods'].languageTerm(:type => "code", :authority => "iso639-2b"){
                new_mods.text(parts[0])
              }
            }
          end
        end

        #34"extent desc.",35"page start",36"page end",37"page range",
        new_mods['mods'].physicalDescription{
          new_mods['mods'].form("text")          
          new_mods['mods'].extent(line_arr[34])
        } unless line_arr[34] == ""


        #38"Topics, ; separated",
        unless line_arr[38] == ""
          subj = line_arr[38].split(';')
          subj.each do |topic|
            new_mods['mods'].subject{
                new_mods['mods'].topic(topic)
            }
          end
        end

        #39"series title",
        unless line_arr[39] == ""
          new_mods['mods'].relatedItem(:type => "series"){
            new_mods['mods'].titleInfo{
              new_mods['mods'].title(line_arr[39])
            }
          }
        end

        #40"location (label|url;etc)"
        unless line_arr[40] == ""
          locs = line_arr[40].split(';')
          locs.each do |part|
            parts =  part.split('|')
            new_mods['mods'].location{
              new_mods['mods'].url(:displayLabel => parts[0]){
                new_mods.text(parts[1])
              }
            }
          end
        end
      }
    end
    return builder.to_xml
  end


end