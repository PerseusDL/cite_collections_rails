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

  def import
    @error_report = File.open("#{BASE_DIR}/catalog_pending/errors/error_log#{Date.today}.txt", 'w')
    @paths_file = File.open("#{BASE_DIR}/catalog_pending/errors/paths.txt", 'w')
    pending_mads = "#{BASE_DIR}/catalog_pending/mads"
    pending_mods = "#{BASE_DIR}/catalog_pending/mods"
    corrections = "#{BASE_DIR}/catalog_data"

    #update_git_dir("catalog_pending") UNCOMMENT THIS
    update_from_catalog_data(corrections)
    #mads_import(pending_mads)
    mods_import(pending_mods)

    #remove all the now empty directories, leaving only the files that encountered errors
    delete_dirs(pending_mads)
    delete_dirs(pending_mods)
  end

  def mads_import(pending_mads)
    all_mads_dirs = clean_dirs(pending_mads)
    mads_files = []
    all_mads_dirs.each {|file| mads_files << file unless file =~ /marc/}
    mads_files.each do |mads|
      begin
        mads_xml = get_xml(mads)
        has_cts = mads_xml.search("/mads:mads/mads:identifier[@type='ctsurn']")
        unless has_cts.empty? || has_cts.inner_text == ""
          ctsurn = has_cts.inner_text
          info_hash = find_basic_info(mads_xml, mads, ctsurn)
        else
          info_hash = find_basic_info(mads_xml, mads)
        end
        #if it already exists we don't need to add it to the table again
        if info_hash
          unless info_hash[:cite_auth].empty?
            Author.update_row(info_hash, "auto_importer")
            next
          else
            add_to_cite_tables(info_hash)

            new_auth = Author.get_by_id(info_hash[:canon_id])[0]
            #add cite urn to record
            id_line = mads_xml.search("/mads:mads/mads:identifier").last
            n_id = Nokogiri::XML::Node.new "mads:identifier", mads_xml
            n_id.add_namespace_definition("mads", "http://www.loc.gov/mads/v2")
            n_id.content = new_auth.urn
            n_id.set_attribute("type", "citeurn")
            id_line.add_next_sibling(n_id)

            madspath = create_mads_path(mads)
            @paths_file << "#{new_auth.urn}, #{madspath}\n\n"
            move_file(madspath, mads_xml)
            #remove the successfully imported file from catalog_pending
            FileUtils.rm(mads)
          end
        else
          message = "For file #{mads} : No info hash returned, something has gone wrong, please check."
          error_handler(message, true)
        end
      rescue
        message = "caught the lower exceptions"
        error_handler(message, false)
      end
    end
    #remove all the marc records
    FileUtils.rm Dir.glob("#{pending_mads}/**/*.marcxml.xml")
  end

  def mods_import(pending_mods)
    mods_files = clean_dirs(pending_mods)
    mods_files.each do |mods|
      begin
        success = add_mods(mods)
        if success
          #remove the successfully imported file from catalog_pending
          FileUtils.rm(mods)
        end 
      rescue
        message = "#{mods} import failed"
        error_handler(message, false)
      end
    end
  end

  def add_mods(mods)
    ctsurn = ""
    mods_xml = ""
    begin
      file_path = mods
      mods_xml = get_xml(file_path)
      #need to check that the mods prefix exists and if not, add it
      namespaces = mods_xml.namespaces
      unless namespaces.include?("xmlns:mods")
        add_mods_prefix(mods_xml)
        File.open(file_path, "w"){|file| file << mods_xml}
        new_xml = get_xml(file_path)
        it_worked = new_xml.search("/mods:mods/mods:titleInfo")
        if it_worked == nil || it_worked.empty?
          message = "For file #{file_path}: tried adding prefix to mods but something went wrong, please check"
          error_handler(message, true)
        else
          mods_xml = new_xml
        end
      end

      has_cts = mods_xml.search("/mods:mods/mods:identifier[@type='ctsurn']")
      unless has_cts.empty? || has_cts.inner_text == ""
        #record already has a cts urn, could be added mods or multivolume record
        #also need to check to make sure the ctsurn is in the correct format, doesn't just give a work urn
        ctsurn = has_cts.inner_text
        vers = Version.find_by_cts(ctsurn)  
        same = nil
        vers.each {|v| same = ((v.version == ctsurn && v.urn_status == "published") ? v : nil) if v}
        if same
          work_row = Work.find_by_work(ctsurn[/urn:cts:\w+:\w+\.\w+/])
          label, description = create_label_desc(mods_xml)
          full_label = work_row.title_eng + ", " + label
          if same.has_mods == "false"
            #has cite row, lacking a mods, update accordingly 
            Version.update(same.id, {:has_mods => "true", :edited_by => "auto_importer"})
            modspath = create_mods_path(ctsurn)                           
            move_file(modspath, mods_xml)
          else
            #if has row and confirmed mods, not a correction, assumed multivolume, just move to correct place
            Version.update_row(ctsurn, full_label, description, "auto_importer")
            modspath = create_mods_path(ctsurn)                           
            move_file(modspath, mods_xml)
          end
        else
          #has a ctsurn but no cite row, for whatever reason, needs to be added
          #check that the ctsurn has a valid structure
          if ctsurn =~ /urn:cts:\w+:\w+\.\w+\.\w+/
            unless mods_xml.search("//mods:relatedItem[@type='constituent']").empty?
              #has constituent items, needs to be passed to a method to create new mods
              split_constituents(mods_xml, mods)
            else
              info_hash = find_basic_info(mods_xml, mods, ctsurn[/urn:cts:\w+:\w+\.\w+/])           
              if info_hash
                add_to_cite_tables(info_hash, mods_xml)
                #add to versions table
                puts "going into add version"
                add_to_vers_table(info_hash, mods_xml, ctsurn)
              else
                message = "For file #{file_path} : No info hash returned, something has gone wrong, please check. #{$!}"
                error_handler(message, true)
              end
            end
          else
            message = "cts urn for #{file_path}, #{ctsurn}, is not valid"
            error_handler(message, true)
          end
        end
      else
        unless mods_xml.search("//mods:relatedItem[@type='constituent']").empty?
          #has constituent items, needs to be passed to a method to create new mods
          split_constituents(mods_xml, mods)
        else
          info_hash = find_basic_info(mods_xml, mods)
          #have the info from the record and cite tables, now process it
          #:file_name,:canon_id,:a_name,:tg_id,:alt_ids,:cite_auth,:cite_tg :w_title,:w_id,:cite_work,:w_lang
          if info_hash
              add_to_cite_tables(info_hash, mods_xml)
              #add to versions table
              puts "going into add version"
              add_to_vers_table(info_hash, mods_xml)

          else
            message = "For file #{file_path} : No info hash returned, something has gone wrong, please check. #{$!}"
            error_handler(message, true)
          end
        end
      end
    rescue
      message = "The import for this file, #{mods} failed\n#{$!}"
      error_handler(message, false)
      return false
    end
    puts "successful import"
    return true
  end




  

  def split_constituents(mods_xml, file_path)
    #create a new mods file for each constituent item
    
    const_nodes = mods_xml.search("//mods:relatedItem[@type='constituent']")
    const_nodes.each_with_index do |const, i|

      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml['mods'].mods('xmlns:mods' => 'http://www.loc.gov/mods/v3') {
          xml['mods'].relatedItem(:type => 'host')
        }
      end

      const.children.each do |sib|
        builder.doc.xpath("//mods:relatedItem")[0].add_previous_sibling(sib.clone)
      end
      mods_xml.root.children.each do |child|
        
        unless child.name == "relatedItem"
          builder.doc.xpath("//mods:relatedItem")[0].add_child(child.clone)
        end
      end

      info_hash = find_basic_info(builder.doc, file_path)
      if info_hash
        begin
          add_to_cite_tables(info_hash, builder.doc)
          add_to_vers_table(info_hash, builder.doc)
        rescue Exception => e
          split_const_error(file_path, builder.doc, i)
        end
      else
        split_const_error(file_path, builder.doc, i)
      end
    end
  end

  def split_const_error(file_path, doc, i)
    new_path = file_path.chomp(".xml") + "const#{i}.xml"
    move_file(new_path, doc)
    new_name = new_path[/(\/[a-zA-Z0-9\s\.\(\)-]+)?\.xml/]
    message = "For file #{new_path}: constituent failed, saving new constituent record"
    error_handler(message, false)
  end

  def update_from_catalog_data(path)   
    changes = get_recent_changes(path) 
    editor = "auto_importer"     
    changes.each do |file_path|
      begin
        mods_xml = get_xml(file_path)
        has_cts = mods_xml.search("/mods:mods/mods:identifier[@type='ctsurn']")
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


end