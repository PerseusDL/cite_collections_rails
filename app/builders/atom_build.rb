#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

class AtomBuild
  require 'nokogiri'
  require 'mechanize'
  include ApplicationHelper

  TI_NS = 'http://chs.harvard.edu/xmlns/cts/ti'
  ATOM_NS = 'http://www.w3.org/2005/Atom'
  MODS_NS = 'http://www.loc.gov/mods/v3'
  MADS_NS = 'http://www.loc.gov/mads/v2'

  def set_up_feeds(type)
    st = Time.now      
    today_date = st.strftime("%Y%m%d")

    #create the feed directory if it doesn't exist
    @feed_directories = "#{BASE_DIR}/FRBR.feeds.#{today_date}"
    unless File.directory?(@feed_directories)
      Dir.mkdir(@feed_directories)
      Dir.mkdir("#{@feed_directories}/greekLit")
      Dir.mkdir("#{@feed_directories}/latinLit")
    end

    @mads_directory = "#{@feed_directories}/mads"
    unless File.directory?(@mads_directory)
      Dir.mkdir(@mads_directory)
    end

    @error_file = File.new("#{@feed_directories}/errors.txt", 'w')

    if type == "all"    
      work_list = Work.all
      start_feeds(work_list)
    elsif type == "latest"
      changes = get_recent_changes("#{BASE_DIR}/catalog_data")
      work_list = []
      changes.each do |file_name|
        begin
          #for each mads file need to pull their works, as all author updates need
          #to be propagated through the feeds
          #for each mods file, need to get the work row
          
          if file_name =~ /mads/
            shorter = file_name[/PrimaryAuthors.+/]
            auth = Author.find_by_mads_file(shorter)
            rel_works = auth.related_works.gsub(';', '|')
          else
            w_id = file_name[/\/\w+\.\w+/].gsub("/", '')
            rel_works = Work.find_by_work(w_id)
          end
          works = Work.all(:conditions => ["work rlike ?", rel_works])
          work_list = work_list + works
        
        rescue Exception => e
        puts "Something went wrong for file #{file_name}! #{$!}"
        @error_file << "#{$!}\n#{e.backtrace}\n\n"
        @error_file.close
        @error_file = File.open("#{@feed_directories}/errors.txt", 'a')
        end
      end
      start_feeds(work_list.uniq)
    end
    puts "Feed build started at #{st}"
    puts "Feed build completed at #{Time.now}"
  end


  def start_feeds(work_list)
    work_list.each do |work_row|
      begin 
        build_feeds(work_row)
      rescue Exception => e
      puts "Something went wrong for work_row #{work_row.work}! #{$!}"
      @error_file << "#{$!}\n#{e.backtrace}\n\n"
      @error_file.close
      @error_file = File.open("#{@feed_directories}/errors.txt", 'a')
      end
    end
  end
  

  def build_feeds(work_row)
    catalog_dir = "#{BASE_DIR}/catalog_data"
    begin
      if work_row.urn_status == "published"
        @w_urn = work_row.work
        @tg_urn = @w_urn[/urn:cts:\w+:\w+/]
        @w_title = work_row.title_eng
        @w_lang = work_row.orig_lang
        @lit_type = @tg_urn[/\w+Lit/]
        @tg_id = @tg_urn[/\w+$/]
        @tg_name = Textgroup.find_by_id(@tg_urn).groupname_eng
        @w_id = @w_urn[/\w+$/]
        tg_dir = "#{@feed_directories}/#{@lit_type}/#{@tg_id}"
        unless File.directory?("#{@feed_directories}/#{@lit_type}")
          Dir.mkdir("#{@feed_directories}/#{@lit_type}")
        end
        unless File.directory?(tg_dir)
          #create the tg_feed and populate the header          
          make_dir_and_feed(tg_dir, "#{@feed_directories}/#{@lit_type}", "textgroup")         
        end

        #open tg_feed for current state and make sure that the formatting will be nice
        tg_xml = get_xml("#{tg_dir}.atom.xml")
        tg_marker = find_node("//ti:textgroup", tg_xml, {"ti" => TI_NS})
        #add the work info to the tg_feed header
        tg_builder = add_work_node(tg_marker)

        #create the work_feed and open the file for proper formatting of info to be added
        work_dir = "#{tg_dir}/#{@w_id}"
        make_dir_and_feed(work_dir, @feed_directories, "work")
        work_xml = get_xml("#{@feed_directories}/#{@tg_id}.#{@w_id}.atom.xml")
        work_marker = find_node("//ti:textgroup", work_xml, {"ti" => TI_NS})
        work_builder = add_work_node(work_marker)

        mads_cts = Author.get_by_id(@tg_id)
        mads_num = 1
        @mads_arr =[]
        unless mads_cts.empty?
          mads_cts.each do |author| 
            if author.urn_status == "published"         
              mads_path  = author.mads_file
              mads_xml = get_xml("#{catalog_dir}/mads/#{mads_path}")
              # Nokogiri is doing funky things with namespaces
              # clear them out and make sure the mods prefix is fully there
              mads_xml.remove_namespaces!
              add_mads_prefix(mads_xml)
              mads_urn = author.canonical_id
              @mads_arr << [mads_urn, mads_num, mads_path, mads_xml]
              mads_num += 1  
            end          
          end

        end

        #grab all mods files for the current work and iterate through
        work_mods_dir = "#{catalog_dir}/mods/#{@lit_type}/#{@tg_id}/#{@w_id}"
        ids_done = []
        if File.directory?(work_mods_dir)
          entries_arr = Dir.entries(work_mods_dir)
          entries_arr.each do |sub_dir|
            unless sub_dir == "." or sub_dir ==".." or sub_dir == ".DS_Store"
              
              mods_arr = Dir.entries("#{work_mods_dir}/#{sub_dir}")
              mods_arr.each do |m_f|   

                unless m_f == "." or m_f ==".." or m_f == ".DS_Store"
                  @ver_id = sub_dir
                  @ver_urn = "#{@w_urn}.#{@ver_id}"
                  ver_row = Version.find_by_version(@ver_urn)
                  unless (ver_row) 
                    puts "Can't find Version #{@ver_urn}"
                    raise "No version #{@ver_urn}"
                  end
                  ver_type = ver_row.ver_type
                  @mods_num = m_f[/mods\d+/] #need to add in a dash between the mods and the number
                  ids_done << ver_row.version
                  #create ver_feed head
                  make_dir_and_feed(work_dir, work_dir, ver_type)
                  ver_xml = get_xml("#{work_dir}/#{@tg_id}.#{@w_id}.#{@ver_id}.atom.xml")
                  ver_marker = find_node("//ti:textgroup", ver_xml, {"ti" => TI_NS})
                  #add the work info to the ver_feed header
                  ver_builder = add_work_node(ver_marker)

                  #open the mods file once we have it
                  mods_xml = get_xml("#{work_mods_dir}/#{sub_dir}/#{m_f}") if m_f =~ /\.xml/

                  
                  # Nokogiri is doing funky things with namespaces
                  # clear them out and make sure the mods prefix is fully there
                  mods_xml.remove_namespaces!
                  add_mods_prefix(mods_xml)
                  
                  #TO DO: need to add a re assignment of @ver_urn if more than one mods for an ed?
                 
                  params = {
                    "docs" => [tg_builder, work_builder, ver_builder],
                    "label" => ver_row.label_eng,
                    "description" => ver_row.desc_eng,
                    "lang" => @w_lang,
                    "type" =>ver_type
                  }
                  
                  add_ver_node(params)
                  
                  mods_head = build_mods_head(ver_type)
                  content = find_node("//atom:content", mods_head.doc, {"atom" => ATOM_NS})
                  content.add_child(mods_xml.root)
                  add_mods_node(params['docs'], mods_head)

                  ver_mads = build_mads_head(ver_builder)
                  add_mads_node(ver_builder, ver_mads)


                  ver_file = File.open("#{work_dir}/#{@tg_id}.#{@w_id}.#{@ver_id}.atom.xml", 'w')
                  ver_file << ver_builder.to_xml
                  ver_file.close
                end
              end
            end
          end 
          #could also have versions without mods, need to catch those too
          all_rows = Version.where("version rlike ? and urn_status = 'published'", @w_urn)
          all_rows.each do |row|
            unless ids_done.include?(row.version)
              params = {
                "docs" => [tg_builder, work_builder],
                "label" => row.label_eng,
                "description" => row.desc_eng,
                "lang" => @w_lang,
                "type" => row.ver_type
              }
              add_ver_node(params)
            end
          end
        end
        #putting this here so we can save works without versions and not have weird stub atom files
        #since the tg feed is opened and added to each don't want to do that multiple times
        unless has_mads?(tg_builder)
          tg_mads = build_mads_head(tg_builder)
          add_mads_node(tg_builder, tg_mads)
        end
        tg_file = File.open("#{@feed_directories}/#{@lit_type}/#{@tg_id}.atom.xml", 'w')
        tg_file << tg_builder.to_xml
        tg_file.close

        work_mads = build_mads_head(work_builder)
        add_mads_node(work_builder, work_mads)
        work_file = File.open("#{@feed_directories}/#{@tg_id}.#{@w_id}.atom.xml", 'w')
        work_file << work_builder.to_xml
        work_file.close
      end
    rescue Exception => e
      puts "Something went wrong for #{work_row.work} in build_fields! #{$!} #{e.backtrace}"
      @error_file << "#{$!}\n#{e.backtrace}\n\n"
      @error_file.close
      @error_file = File.open("#{@feed_directories}/errors.txt", 'a')
    end    
  end


  def make_dir_and_feed(dir, dir_base, type)
    Dir.mkdir(dir) unless File.directory?(dir)
     
    #constructing feed files
    if type == "textgroup"
      atom_name = "#{dir_base}/#{@tg_id}.atom.xml"
    elsif type == "work"
      atom_name = "#{dir_base}/#{@tg_id}.#{@w_id}.atom.xml"
    else
      atom_name ="#{dir_base}/#{@tg_id}.#{@w_id}.#{@ver_id}.atom.xml"
    end 

    unless File.exists?(atom_name)  
      feed = build_feed_head(type)
      feed_file = File.new(atom_name, 'w')
      feed_file << feed.to_xml
      feed_file.close
    end
  end

  #xml creation/manipulation methods

  def build_feed_head(feed_type)
    
    if feed_type =~ /textgroup/
      atom_id = "http://data.perseus.org/catalog/#{@tg_urn}/atom"
      atom_urn = @tg_urn
    elsif feed_type =~ /work/
      atom_id = "http://data.perseus.org/catalog/#{@w_urn}/atom"
      atom_urn = @w_urn
    else
      atom_id = "http://data.perseus.org/catalog/#{@ver_urn}/atom"
      atom_urn = @ver_urn
    end
     
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |a_feed|

      #the first section, before the actual text inventory begins is the same for all feed levels
      #only items that change are variables for ids/urls and basic text in the titles
      a_feed.feed('xmlns:atom' => 'http://www.w3.org/2005/Atom'){
        a_feed.parent.namespace = a_feed.parent.namespace_definitions.find{|ns|ns.prefix=="atom"}        
        a_feed['atom'].id_(atom_id)
        a_feed['atom'].author('Perseus Digital Library')
        a_feed['atom'].rights('This data is licensed under a Creative Commons Attribution-ShareAlike 3.0 United States License')
        a_feed['atom'].title("The Perseus Catalog: atom feed for CTS #{feed_type} #{atom_urn}") 
        a_feed['atom'].link(:type => 'application/atom+xml', :rel => 'self', :href => atom_id) 
        a_feed['atom'].link(:type => 'text/html', :rel => 'alternate', :href => "http://catalog.perseus.org/catalog/#{atom_urn}")
        a_feed['atom'].updated(Time.now)
        a_feed['atom'].entry {
          a_feed['atom'].id_("#{atom_id}#ctsti")
          a_feed['atom'].author('Perseus Digital Library')
          a_feed['atom'].link(:type => 'application/atom+xml', :rel => 'self', :href => "#{atom_id}#ctsti")
          a_feed['atom'].link(:type => 'text/html', :rel => 'alternate', :href => "http://catalog.perseus.org/catalog/#{atom_urn}")
          a_feed['atom'].title {
            a_feed.text( if feed_type =~ /textgroup|work/
              "The Perseus Catalog: Text Inventory for CTS #{feed_type} #{atom_urn}"
            else
              "The Perseus Catalog: Text Inventory excerpt for CTS #{feed_type} #{atom_urn}"
            end)
          }
          #Text inventory start
          a_feed['atom'].content(:type => 'text/xml') {
            a_feed.TextInventory('xmlns:ti' => TI_NS) {
              a_feed.parent.namespace = a_feed.parent.namespace_definitions.find{|ns|ns.prefix=="ti"}        
              a_feed.ctsnamespace('xmlns:ti' => TI_NS, :abbr => "greekLit", :ns => "http://perseus.org/namespaces/cts/greekLit"){
                a_feed.descripton('xmlns:ti' => TI_NS, 'xml:lang' => 'eng'){a_feed.text("Greek texts hosted by the Perseus Digital Library")}
              }

              a_feed.ctsnamespace('xmlns:ti' => TI_NS, :abbr => "latinLit", :ns => "http://perseus.org/namespaces/cts/latinLit"){
                a_feed.descripton('xmlns:ti' => TI_NS, 'xml:lang' => 'eng'){a_feed.text("Latin texts hosted by the Perseus Digital Library")}
              }

              a_feed.collection('xmlns:ti' => TI_NS, :id => 'Perseus:collection:Greco-Roman', :isdefault => 'yes'){
                a_feed.title('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Greek and Roman Materials')}
                a_feed.creator('xmlns' => 'http://purl.org/dc/elements/1.1/'){a_feed.text('The Perseus Digital Library')}
                a_feed.coverage('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Primary and secondary sources for the study of ancient Greece
      and Rome')}
                a_feed.descripton('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Primary and secondary sources for the study of ancient Greece
      and Rome')}
                a_feed.rights('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Licensed under a Creative Commons Attribution-ShareAlike 3.0 United States License')}
              }

              a_feed.collection('xmlns:ti' => TI_NS, :id => 'Perseus:collection:Greco-Roman-protected'){
                a_feed.title('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Greek and Roman Materials')}
                a_feed.creator('xmlns' => 'http://purl.org/dc/elements/1.1/'){a_feed.text('The Perseus Digital Library')}
                a_feed.coverage('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Primary and secondary sources for the study of ancient Greece
      and Rome')}
                a_feed.descripton('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Primary and secondary sources for the study of ancient Greece
      and Rome')}
                a_feed.rights('xmlns' => 'http://purl.org/dc/elements/1.1/', 'xml:lang' => 'eng'){a_feed.text('Content is under copyright.')}
              }
              #Textgroup name
              a_feed.textgroup(:urn => @tg_urn){
                a_feed.groupname('xmlns:ti' => TI_NS, 'xml:lang' => "eng"){
                  a_feed.text(@tg_name)
                }
              }
            }
          }
        }
      }
      
    end
    return builder    
  end

  def find_node(n_xpath, xml_doc, ns, urn = false)
    ns = xml_doc.collect_namespaces unless ns
    n_xpath = "#{n_xpath}[@urn='#{@w_urn}']" if urn
    target_node = xml_doc.xpath(n_xpath, ns).last
  end


  def add_work_node(marker_node)       
    builder = Nokogiri::XML::Builder.with(marker_node) do |feed|
      feed.work('xmlns:ti' => TI_NS, :urn => @w_urn, 'xml:lang' => "#{@w_lang}", :groupUrn => @tg_urn){
        feed.title('xmlns:ti' => TI_NS, 'xml:lang' => "#{@w_lang}"){
          feed.text(@w_title)
        }
      }
    end
    return builder
  end


  def add_ver_node(params)
    #params hash: "docs" => [tg_builder, work_builder, ver_builder], "label" => label, "description" => description,
    #             "lang" => orig_lang, "type" =>ver_type
    params["docs"].each do |doc|
      node = find_node("//ti:work", doc.doc, { 'ti' => TI_NS }, true)
      builder = Nokogiri::XML::Builder.with(node) do |feed|
        feed.send("#{params['type']}", "xmlns:ti" => TI_NS, 'urn' => @ver_urn, 'workUrn' => @w_urn){
          feed.label('xml:lang' => 'eng'){feed.text(params['label'])}
          feed.description('xml:lang' => 'eng'){feed.text(params['description'])}
        }
      end
    end
  end


  def build_mods_head(type)
    atom_id = "http://data.perseus.org/catalog/#{@ver_urn}/atom#mods-#{@mods_num}"
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |a_feed|
      a_feed.feed('xmlns:atom' => 'http://www.w3.org/2005/Atom'){
        a_feed.parent.namespace = a_feed.parent.namespace_definitions.find{|ns|ns.prefix=="atom"}
        a_feed['atom'].entry{
          a_feed['atom'].id_(atom_id)
          a_feed['atom'].author('Perseus Digital Library')
          a_feed['atom'].title("MODS file for CTS #{type} #{@ver_urn}")
          a_feed['atom'].link(:type => 'application/atom+xml', :rel => 'self', :href => atom_id) 
          a_feed['atom'].link(:type => 'text/html', :rel => 'alternate', :href => "http://catalog.perseus.org/catalog/#{@ver_urn}")
          a_feed['atom'].content(:type => 'text/xml')
        }
      }
    end
    return builder
  end


  def add_mods_node(builders, mods_head)
    begin
      builders.each do |builder|
        if has_mads?(builder)
          first_mads = builder.doc.xpath("//atom:link[@href='http://data.perseus.org/collections/#{@mads_arr[0][0]}']")
          right_entry = first_mads[0].parent
          right_entry.add_previous_sibling(find_node("//atom:entry", mods_head.doc, {"atom" => ATOM_NS}).clone)
        else
          builder.doc.root.add_child(find_node("//atom:entry", mods_head.doc, {"atom" => ATOM_NS}).clone)  
          
          #for some reason the mods prefix definition is removed when adding perseus records, have to add it back
          if @ver_id =~ /perseus/
            perseus_mods = find_node("//atom:entry/atom:content", builder.doc, {"atom" => ATOM_NS}).child
            perseus_mods.add_namespace_definition('mods', 'http://www.loc.gov/mods/v3')
          end

        end
      end
    rescue Exception => e
      puts "Something went wrong for #{@w_urn} in add_mods_mode! #{$!} #{e.backtrace}"
      @error_file << "#{$!}\n#{e.backtrace}\n\n"
      @error_file.close
      @error_file = File.open("#{@feed_directories}/errors.txt", 'a')
    end

  end


  def has_mads?(builder)
    builder.doc.inner_text =~ /The Perseus Catalog: MADS file/ ? true : false
  end

  #might eventually create atom feeds for the mads too
  def build_mads_head(builder)
    mads_heads = []
    @mads_arr.each do |arr|
      #@mads arr contains 0mads_urn, 1mads_num, 2mads_path, 3mads_xml
      atom_id_node = find_node("atom:feed/atom:id", builder.doc, {"atom" => ATOM_NS})
      if atom_id_node.inner_text =~ /#{@tg_urn}\/atom/
        type = "textgroup"
        atom_id = "http://data.perseus.org/catalog/#{@tg_urn}/atom#mads-#{arr[1]}"
        urn = @tg_urn
      else 
        type = "work"
        urn = @w_urn
        if atom_id_node.inner_text =~ /#{@w_urn}\/atom/
          atom_id = "http://data.perseus.org/catalog/#{@w_urn}/atom#mads-#{arr[1]}"
        else
          atom_id = "http://data.perseus.org/catalog/#{@ver_urn}/atom#mads-#{arr[1]}"
        end        
      end
      #the atom:links and some text below will probably change when we properly label our authors in the mysql database
      m_builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |a_feed|
        a_feed.feed('xmlns:atom' => 'http://www.w3.org/2005/Atom'){
          a_feed.parent.namespace = a_feed.parent.namespace_definitions.find{|ns|ns.prefix=="atom"}
          a_feed['atom'].entry{
            a_feed['atom'].id_(atom_id)
            a_feed['atom'].link(:type => "application/atom+xml", :rel => 'self', :href => atom_id)
            a_feed['atom'].link(:type => "text/xml", :rel => "alternate", :href => "http://data.perseus.org/collections/#{arr[0]}")
            a_feed['atom'].author('Perseus Digital Library')
            a_feed['atom'].title("The Perseus Catalog: MADS file for author of CTS #{type} #{urn}")
            a_feed['atom'].content(:type => 'text/xml')            
          }
        }
      end
      mads_heads << m_builder
    end
    return mads_heads
  end

  def add_mads_node(builder, mads_heads)
    mads_heads.each do |head|
      num = head.doc.xpath('//atom:id').inner_text[/\d+$/]
      arr = @mads_arr.rassoc(num.to_i)
      content = find_node("//atom:content", head.doc, {"atom" => ATOM_NS})
      content.add_child(arr[3].clone.root)
      
      #make a mads atom file
      id = arr[0][/author.\d+.\d/]
      unless File.exists?("#{@mads_directory}/#{id}.atom.xml")
        mads_atom = File.new("#{@mads_directory}/#{id}.atom.xml", 'w')
        mads_atom << head.doc.clone
        mads_atom.close
      end

      builder.doc.root.add_child(find_node("//atom:entry", head.doc, {"atom" => ATOM_NS}).clone)
    end
  end

end
