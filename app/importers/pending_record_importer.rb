#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================


class PendingRecordImporter
  include CiteColls
  include ApplicationHelper
  require 'fileutils'

  def import(base_dir)
    @base_dir = base_dir.nil? ? BASE_DIR : base_dir
    @error_report = File.open("#{@base_dir}/catalog_pending/errors/error_log#{Date.today}.txt", 'w')
    @paths_file = File.open("#{@base_dir}/catalog_pending/errors/paths.txt.#{Date.today}", 'w')
    pending_mads = "#{@base_dir}/catalog_pending/mads"
    pending_mods = "#{@base_dir}/catalog_pending/mods"
    corrections = "#{@base_dir}/catalog_data"

    #update_git_dir("catalog_pending") UNCOMMENT THIS ??
    # We are explicitly disabling the update of the cite collections from the catalog data
    # for now. Fixes can be made directly in the cite collections tables
    # update_from_catalog_data(corrections) 
    mads_import(pending_mads)
    mods_import(pending_mods)

    #remove all the now empty directories, leaving only the files that encountered errors
    delete_dirs(pending_mads)
    delete_dirs(pending_mods)
  end

  def mads_import(pending_mads)
    all_mads_dirs = clean_dirs(pending_mads,'mads')
    mads_files = []
    all_mads_dirs.each {|file| mads_files << file unless file =~ /marc/}
    mads_files.each do |mads|
      begin
        mads_xml = get_xml(mads)
        has_cts = mads_xml.xpath("/mads:mads/mads:identifier[@type='ctsurn']", {"mads" => "http://www.loc.gov/mads/v2"})
        unless has_cts.empty? || has_cts.inner_text == ""
          ctsurn = has_cts.inner_text
          info_hash = find_basic_info(mads_xml, mads, ctsurn)
        else
          info_hash = find_basic_info(mads_xml, mads)
        end
        #if it already exists we don't need to add it to the table again
        madspath = create_mads_path(mads)
        if info_hash
          unless info_hash[:cite_auth].empty?
            info_hash[:mads_file] = madspath[/PrimaryAuthors.+\.xml/]         
            #update the path to the mads file
            Author.update_row(info_hash, "auto_importer")
          else
            add_to_cite_tables(info_hash)
            new_auth = Author.get_by_id(info_hash[:canon_id])[0]
            #add cite urn to record
            id_line = mads_xml.xpath("/mads:mads/mads:identifier",{"mads" => "http://www.loc.gov/mads/v2"}).last
            n_id = Nokogiri::XML::Node.new "identifier", mads_xml
            n_id.add_namespace_definition(nil, "http://www.loc.gov/mads/v2")
            n_id.content = new_auth.urn
            n_id.set_attribute("type", "citeurn")
            id_line.add_next_sibling(n_id)
          end
          move_file(madspath, mads_xml)
          #remove the successfully imported file from catalog_pending
          FileUtils.rm(mads)
        else
          message = "For file #{mads} : No info hash returned, something has gone wrong, please check."
          error_handler(message, true)
        end
      rescue Exception => e
        message = "caught the lower exceptions #{e} #{e.backtrace}"
        error_handler(message, false)
      end
    end
    #remove all the marc records
    FileUtils.rm Dir.glob("#{pending_mads}/**/*.marcxml.xml")
  end

  def mods_import(pending_mods)
    mods_files = clean_dirs(pending_mods,'mods')
    mods_files.each do |mods|
      begin
        success = add_mods(mods)
        if success
          #remove the successfully imported file from catalog_pending
          FileUtils.rm(mods)
          @paths_file << "#{mods}\n\n"
        end       
      rescue Exception => e
        message = "#{mods} import failed"
        error_handler(message + "#{e.backtrace}", false)
      end
    end
  end

  def add_mods(file_path)
    puts "starting import of #{file_path}"
    ctsurn = nil
    mods_xml = ""
    begin
      mods_xml = get_xml(file_path)
      # make sure the file is fully in the mods namespace
      add_mods_prefix(mods_xml)
      File.open(file_path, "w"){|file| file << mods_xml}
      new_xml = get_xml(file_path)
      it_worked = new_xml.xpath("//mods:mods/mods:titleInfo",{"mods" => "http://www.loc.gov/mods/v3"})
      if it_worked == nil || it_worked.empty?
        message = "For file #{file_path}: tried adding prefix to mods but something went wrong, please check"
        error_handler(message, true) # raises error
      else
        mods_xml = new_xml
      end
      parsed = parse_collection(mods_xml) 

      # TODO we should maybe check to see of the other records have a ctsurn if the first doesn't due to human error?
      has_cts = parsed[:first_record].xpath("/mods:mods/mods:identifier[@type='ctsurn']", {"mods" => "http://www.loc.gov/mods/v3"})

      unless (has_cts.empty? || has_cts.inner_text == "") 
        ctsurn = has_cts.inner_text
      end

      update_only = false
      mods_files = [] 

      if ctsurn != nil && ctsurn !~ /urn:cts:\w+:\w+\.\w+\.\w+/
        #check that the ctsurn has a valid structure
        message = "cts urn for #{file_path}, #{ctsurn}, is not valid"
        error_handler(message, true) # raises error and aborts processing of this mods file
      end

      # if we are processing a mods file which has already a cts_urn, it should be only one of the following scenarios:
      # 1. we are replacing an existing mods file with mods collection file
      # 2. we are processing a mods file for a version which had a cts urn but no mods file 
      # 3. it is a work level cts urn and a new version level urn needs to be assigned
      if (ctsurn != nil) 
        vers = Version.find_by_cts(ctsurn)  
        # the mods file is for an existing cts version if # the cts urn in the mods file matches a version level cts urn of a published or reserved cts version record 
        # @TODO WHAT HAPPENS IF WE ARE PROCESSING A MODS FILE FOR A ReJECTED OR REDIRECTED RECORD??  
        vers.each {|v| 
          if v && v.version == ctsurn && (v.urn_status == "published" || v.urn_status == "reserved")
            update_only = true
          end
        }
        if update_only
          # we found matching version urn in the cite tables, we just update the metadata and queue the new mods file to be added to catalog_data
          work_row = Work.find_by_work(ctsurn[/urn:cts:\w+:\w+\.\w+/])
          label, description = create_label_desc(parsed[:first_record])
          full_label = work_row.title_eng + ", " + label
          full_label = full_label + ";" + parsed[:range_string] if parsed[:range_string] != ""
          Version.transaction do
            Version.update_row(ctsurn, full_label, description, "auto_importer", true, "published")
            post_mods(ctsurn,mods_xml)
          end
        end
      end

      add_to_cite = []

      if (! update_only)
        parent_mods = {:ctsurn => ctsurn, :record_to_search => parsed[:first_record], :rangestr => parsed[:range_string], :fullrecord => mods_xml}
        # check to see if we have any constituents that we need to parse - we only do this for new cite collection records not updates
        # we explicitly only check the first record if it was a modsCollection - we don't want duplicates
        unless (parsed[:first_record].xpath("//mods:relatedItem[@type='constituent']", {"mods" => "http://www.loc.gov/mods/v3"}).empty?)
          #has constituent items, split them out and add them to the list to add
          add_to_cite = split_constituents(parsed[:first_record])
          # if we have constiuents, we want to mark the parent record as being optional because it might be used only as a vehicle for
          # the consituents
          parent_mods[:optional] = true
        end
        # add the parent mods file to those that potentially need to be added to the cite tables
        # but add it at the end, because it's possible that only the constituents are what we want and we don't want to 
        # fail those if we fail to create a record for the parent
        add_to_cite << parent_mods
      end

      # iterate through the records we need to add to the cite tables to gather metadata and insert into the tables
      constituents_added = 0
      add_to_cite.each do |m|
        begin
          info_hash = find_basic_info(m[:record_to_search], file_path, m[:ctsurn].nil? ? nil : m[:ctsurn[/urn:cts:\w+:\w+\.\w+/]])           
        # metadata calculated, so now we can proceed
          if info_hash
            # add/update the author tg and work metadata 
            ActiveRecord::Base.transaction do
              add_to_cite_tables(info_hash, m[:record_to_search])
              # add this version to the versions table - if we have a ctsurn already it will be returned to us, otherwise we'll be given a new one
              ctsurn = add_to_vers_table(info_hash, m[:record_to_search], m[:ctsurn], m[:rangestr], m[:fullrecord])
            # add the mods file to those we need to move out of pending and into catalog_data
              post_mods(ctsurn,m[:fullrecord])
              if m[:const_num]
                constituents_added = constituents_added + 1
              end
            end
          else
            # metadata gathering failed, we need to report an error
            if m[:const_num]
              # if it was a split consituent, save a copy of what we tried to create but continue
              split_const_error(file_path,m[:fullrecord],m[:const_num])
            elsif m[:optional]
              message = "For file #{file_path} : No info hash returned for parent mods but consituents were parsed. (Constituents successfully added: #{constituents_added})"
              error_handler(message, false)  
            else
              # we want to fail the entire mods file only if the main record it in failed, not a constituent
              message = "For file #{file_path} : No info hash returned, something has gone wrong, please check."
              error_handler(message, true)  
            end
          end
        rescue Exception => e
       # if it was a split consituent, save a copy of what we tried to create
          if m[:const_num]
            split_const_error(file_path,m[:fullrecord],m[:const_num])
          elsif m[:optional]
            message = "Parent mods failure caught and ignored because it has constituents #{file_path} : #{e}."
            error_handler(message, false)  
          else
            # we want to fail the entire mods file only if the main record it in failed, not a constituent
            message = "Error for file #{file_path} : #{e}."
            error_handler(message, true)  
          end
        end
      end
    rescue Exception => e
      message = "The import for this file, #{file_path} failed.";
      error_handler(message + "#{e.backtrace}", false)
      return false
    end
    puts "successful import of #{file_path}"
    return true
  end

  def post_mods(ctsurn, xmldata)
    modspath = create_mods_path(ctsurn)
    move_file(modspath, xmldata)
  end


  def split_constituents(mods_xml)
    #create a new mods file for each constituent item
    new_mods  = []
    const_nodes = mods_xml.search("//mods:relatedItem[@type='constituent']",{"mods" => "http://www.loc.gov/mods/v3"})
    const_nodes.each_with_index do |const, i|

      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.mods('xmlns' => 'http://www.loc.gov/mods/v3') do
            xml.relatedItem(:type => 'host')
          end
      end

      const.children.each do |sib|
        builder.doc.search("//mods:relatedItem", {"mods" => "http://www.loc.gov/mods/v3"})[0].add_previous_sibling(sib.clone)
      end
      mods_xml.root.children.each do |child|
        
        unless child.name == "relatedItem" || child.name == "mods:relatedItem"
          builder.doc.search("//mods:relatedItem", {"mods" => "http://www.loc.gov/mods/v3"})[0].add_child(child.clone)
        end
      end
      # make sure it's all in the mods namespace
      add_mods_prefix(builder.doc)
      new_mods << { :ctsurn => nil, :record_to_search => builder.doc, :rangestr => "", :fullrecord => builder.doc, :const_num => i }
    end
    return new_mods
  end

  def split_const_error(file_path, doc, i)
    new_path = file_path.chomp(".xml") + "const#{i.to_s}.xml"
    move_file(new_path, doc)
    new_name = new_path[/(\/[a-zA-Z0-9\s\.\(\)-]+)?\.xml/]
    message = "For file #{new_path}: constituent failed, saving new constituent record"
    error_handler(message, false)
  end

  def update_from_catalog_data(path)   
    #changes = get_recent_changes(path, since) 
    changes = get_all_modsandmadsfiles(path)
    editor = "auto_importer"     
    changes.each do |file_path|
      begin
        mods_xml = get_xml(file_path)
        namespaces = mods_xml.namespaces
        if (file_path =~ /mads/)
          add_mads_prefix(mods_xml)
          # TODO should rewrite here?
        else
          add_mods_prefix(mods_xml)
          # TODO should rewrite here?
        end
        has_cts = mods_xml.xpath("/mods:mods/mods:identifier[@type='ctsurn']", {"mods" => "http://www.loc.gov/mods/v3"})
        unless has_cts.empty? || has_cts.inner_text == ""
          ctsurn = has_cts.inner_text
          info_hash = find_basic_info(mods_xml, file_path, ctsurn)
        else
          info_hash = find_basic_info(mods_xml, file_path)
        end
        
        if info_hash
          if file_path =~ /mads/              
            Author.update_row(info_hash, editor)
          else
            Textgroup.update_row(info_hash, editor)             
            Work.update_row(info_hash, editor)
            cts = file_path[/\w+\.\w+\.\w+-\w+\d+/]
            vers_label, vers_desc = create_label_desc(mods_xml)
            full_label = info_hash[:w_title] + ", " + vers_label
            Version.update_row(cts, full_label, vers_desc, editor)
          end
        end
      rescue
        message = "Error for catalog_data update, file was was #{file_path}, error message was: #{$!}"
        error_handler(message, false)
      end
    end 
  end

  def parse_collection(mods_xml)
    #dealing with modsCollections/multivolume editions
    collection = mods_xml.xpath("//mods:mods",{"mods" => "http://www.loc.gov/mods/v3"})
    #saving for later use
    range_string = ""
    if collection.length > 1
      ids = []
      collection.each{|x| ids << x.attribute("ID").value}
      ids.sort!
      range = []
      #collect the id ranges
      ids.each_with_index do |x, i|
        unless i == 0
          if i == ids.length - 1
            range << i
          else
            num = x[/\d+/].to_i
            prev = ids[i - 1][/\d+/].to_i
            unless num == prev.next
              range << i - 1 << i
            end
          end
        end
      end
      range_string = ids[0]
      unless range[0] == 0
        range_string << "-#{ids[range[0]]}"
      end
      range.delete_at(0)
      range.each_slice(2){|l, r| range_string << ", #{ids[l]}-#{ids[r]}"}
      # we need to make a new document with the first node of the collection
      # because otherwise nokogiri holds on to the original object and xpaths
      # and searches operate on the original full document and not the individual node
      new_doc = Nokogiri::XML::Document.new()
      new_doc.add_child(collection.first.dup(1))
      return { :range_string => range_string, :first_record => new_doc }
    else
      return { :range_string => "", :first_record => mods_xml }
    end
  end

end
