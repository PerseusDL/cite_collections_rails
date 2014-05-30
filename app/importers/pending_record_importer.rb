class PendingRecordImporter
  include CiteColls
  include ApplicationHelper
  require 'fileutils'

  def import
    @error_report = File.open("#{ENV['HOME']}/catalog_pending/errors/error_log#{Date.today}.txt", 'w')
    pending_mads = "#{ENV['HOME']}/catalog_pending/mads"
    corrected_mads = "#{ENV['HOME']}/catalog_pending/corrections/mads"
    pending_mods = "#{ENV['HOME']}/catalog_pending/mods"
    corrected_mods = "#{ENV['HOME']}/catalog_pending/corrections/mods"

    #update_git_dir("catalog_pending") UNCOMMENT THIS
    mads_import(corrected_mads)
    mods_import(corrected_mods)
    mads_import(pending_mads)
    mods_import(pending_mods)

    #fusion_tables_update
  end

  def mads_import(pending_mads)
    mads_dirs = clean_dirs(pending_mads)
    mads_dirs.each do |name_dir|
      mads = clean_dirs(name_dir).select { |f| f =~ /mads/}[0]
      if mads
        mads_string = File.read(mads)
        mads_xml = Nokogiri::XML::Document.parse(mads_string, &:noblanks)
        info_hash = find_basic_info(mads_xml, mads)
        #if it already exists we don't need to add it to the table again!
        if info_hash #have to account for corrections!
          if info_hash[:cite_auth] && info_hash[:cite_auth].urn_status == "published"
            next
          else
            add_to_cite_tables(info_hash) if info_hash

            new_auth = Author.find_by_id(info_hash[:canon_id])
            #add cite urn to record
            id_line = mads_xml.search("/mads:mads/mads:identifier").last
            n_id = Nokogiri::XML::Node.new "mads:identifier", mads_xml
            n_id.add_namespace_definition("mads", "http://www.loc.gov/mads/v2")
            n_id.content = new_auth.urn
            n_id.set_attribute("type", "citeurn")
            id_line.add_next_sibling(n_id)

            madspath = create_mads_path(mads)
            move_file(madspath, mads_xml)
          end
        else
          message = "For file #{mads} : No info hash returned, something has gone wrong, please check."
          error_handler(message, mads, mads)
        end
      end
    end
  end

  def mods_import(pending_mods)
    mods_dirs = clean_dirs(pending_mods)
    mods_dirs.each do |name_dir|
          
      level_down = clean_dirs(name_dir)
      collect_xml = level_down.select { |f| File.file? f}
      if collect_xml.empty?
        level_down.each do |publisher_dir|
          collect_xml = clean_dirs(publisher_dir)
        end
      end
      collect_xml.each do |mods|
        file_path = mods
        mods_string = File.read(file_path)
        mods_xml = Nokogiri::XML::Document.parse(mods_string, &:noblanks)

        if file_path =~ /corrections/
          #corrections only need to update the row, rename the file and move it 
          ctsurn = mods_xml.search("/mods:mods/mods:identifier[@type='ctsurn']").inner_text
          vers = Version.find_by_cts(ctsurn)
          #should only be one row
          if vers.length == 1
            row = vers[0]
            info_hash = find_basic_info(mods_xml, mods)
            label, description = create_label_desc(info_hash, mods_xml)
            v_lang = mods_xml.search("/mods:mods/mods:relatedItem/mods:language/mods:languageTerm").inner_text
            v_type = info_hash[:orig_lang] == v_lang ? "edition" : "translation"
            Version.update_row(row.id, {:version => ctsurn, :label_eng => label, :desc_eng => description, :type => v_type, :edited_by => "auto_importer"})
            modspath = create_mods_path(ctsurn)                           
            move_file(modspath, mods_xml)
          else
            message = "For file #{file_path}: has more than one of the same cts_urn, should be checked"
            error_handler(message, file_path, ctsurn)
          end

        else
          #need to check that the mods prefix exists and if not, add it
          namespaces = mods_xml.namespaces
          unless namespaces.include?("xmlns:mods")
            add_mods_prefix(mods_xml)
            File.open("#{ENV['HOME']}/catalog_pending/testrename.xml", "w"){|file| file << mods_xml}
            new_mods = File.read("#{ENV['HOME']}/catalog_pending/testrename.xml") #!!will need to change!!
            new_xml = Nokogiri::XML::Document.parse(new_mods, &:noblanks)
            it_worked = new_xml.search("/mods:mods/mods:titleInfo")
            if it_worked == nil || it_worked.empty?
              message = "For file #{file_path}: tried adding prefix to mods but something went wrong, please check"
              error_handler(message, file_path, file_path)
              next
            else
              mods_xml = new_xml
            end
          end

          has_cts = mods_xml.search("/mods:mods/mods:identifier[@type='ctsurn']")
          unless has_cts.empty? || has_cts.inner_text == ""
            #record already has a cts urn, could be added mods or multivolume record
            ctsurn = has_cts.inner_text
            vers = Version.find_by_cts(ctsurn)            
            if vers.length == 1 
              v_obj = vers[0]
              if v_obj.has_mods == "false"
                #has cite row, lacking a mods 
                Version.update_row(v_obj.id, {:has_mods => "true", :edited_by => "auto_importer"})
              end
                #if has row and confirmed mods, not a correction, assumed multivolume, just move to correct place
                modspath = create_mods_path(ctsurn)                           
                move_file(modspath, mods_xml)     
            else
              if vers.length == 0
                #has a ctsurn but no cite row, for whatever reason, needs to be added
                info_hash = find_basic_info(mods_xml, mods)           
                if info_hash
                  add_to_cite_tables(info_hash, mods_xml)
                end
              else
                message = "For file #{file_path}: has more than one of the same cts_urn"
                error_handler(message, file_path, ctsurn)
              end
            end
          else
            unless mods_xml.search("//mods:relatedItem[@type='constituent']").empty?
              #has constituent items, needs to be passed to a method to create new mods
              split_constituents(mods_xml, mods)
            else
              info_hash = find_basic_info(mods_xml, mods)
              #have the info from the record and cite tables, now process it
              #:file_name,:canon_id,:a_name,:a_id,:alt_ids,:cite_auth,:cite_tg :w_title,:w_id,:cite_work,:w_lang
              if info_hash
                  add_to_cite_tables(info_hash, mods_xml)
                  #add to versions table
                  puts "going into add version"
                  add_to_vers_table(info_hash, mods_xml) 
              else
                message = "For file #{file_path} : No info hash returned, something has gone wrong, please check. #{$!}"
                error_handler(message, file_path, file_path)
              end
            end
          end
          #`rm #{file_path}`
        end
      end
    end
  end

  def add_to_cite_tables(info_hash, mods_xml=nil)
    begin
      #auth_col = "urn, authority_name, canonical_id, mads_file, alt_ids, related_works, urn_status, redirect_to, created_by, edited_by"
      #tg_col = "urn, textgroup, groupname_eng, has_mads, mads_possible, notes, urn_status, created_by, edited_by"
      #work_col = "urn, work, title_eng, notes, urn_status, created_by, edited_by"

      unless info_hash[:cite_auth]

        #double check that we don't have a name that matches the author name
        #no row for this author, add a row       
        unless mods_xml
          #only creates rows in the authors table for mads files, so authors acts as an index of our mads, 
          #tgs can cover everyone mentioned in mods files
          a_urn = Author.generate_urn
          mads_path = create_mads_path(info_hash[:path])         
          a_values = ["#{a_urn}", "#{info_hash[:a_name]}", "#{info_hash[:canon_id]}", "#{mads_path}", "#{info_hash[:alt_ids]}", "#{info_hash[:related_works]}", 'published','', 'auto_importer', 'auto_importer']
          Author.add_cite_row(a_values)
        end
        
      else
        #find name returned from cite tables, compare to name from record
        #if they aren't equal, throw an error
        cite_name = info_hash[:cite_auth].authority_name
        cite_auth_id = info_hash[:cite_auth].canonical_id 
        unless cite_auth_id == info_hash[:canon_id] || info_hash[:canon_id] =~ /#{info_hash[:cite_auth].alt_ids}/
          message = "For file #{info_hash[:file_name]}: The author id saved in the CITE table doesn't match the id in the file, please check."
          error_handler(message, info_hash[:path], info_hash[:file_name])
          return
        end
        #need to actually do something with it now, scrape and fill in new info if mads, represents a change to the file?
      end

      unless info_hash[:cite_tg]
        #do we need a name check?
        #no row for this textgroup, add a row
        t_urn = Textgroup.generate_urn
        t_values = ["#{t_urn}", "#{info_hash[:a_id]}", "#{info_hash[:a_name]}", "#{info_hash[:cite_auth] == nil}", 'true','', 'published', 'auto_importer','auto_importer']
        Textgroup.add_cite_row(t_values)
      else
        #if mads, check if mads is marked true, update to true if false
        unless mods_xml
          tg = info_hash[:cite_tg]
          mads_stat = tg.has_mads
          if mads_stat == false
            Textgroup.update_row(tg.id, :has_mads => 'true')
          end
        end
      end
      if mods_xml
        unless info_hash[:cite_work]
          #no row for this work, add a row
          w_urn = Work.generate_urn
          w_values = [w_urn, info_hash[:w_id], info_hash[:w_title], info_hash[:orig_lang], '', 'published', 'auto_importer','auto_importer']
          Work.add_cite_row(w_values)
          puts "added work"
        end

      end

    rescue Exception => e
      if e.message
        message = "#{e.message}, #{e.backtrace}"
      else
        message = "For file #{info_hash[:file_name]}: something went wrong, #{$!}"
      end
      error_handler(message, info_hash[:path], info_hash[:file_name])
      return
    end
  end


  def add_to_vers_table(info_hash, mods_xml)
    begin
      
      #vers_col = "urn, version, label_eng, desc_eng, type, has_mods, urn_status, redirect_to, member_of, created_by, edited_by"
      
        #two (or more) languages listed, create more records
        info_hash[:v_langs].each do |lang|
          puts "in add version"
          vers_type = lang == info_hash[:w_lang] ? "edition" : "translation"
          coll = mods_xml.search("//mods:identifier[@type='Perseus:abo']").empty? ? "opp" : "perseus"
          vers_label, vers_desc = create_label_desc(info_hash, mods_xml)
          vers_urn_wo_num = "#{info_hash[:w_id]}.#{coll}-#{lang}"

          puts "got urn, #{vers_urn_wo_num}"
          #pull all versions that have the work id, returns csv w/first row of column names
          existing_vers = Version.find_by_cts(vers_urn_wo_num)
          #create cts urn off of preexisting entries in version column
          if existing_vers.length == 0
            vers_urn = "#{vers_urn_wo_num}1"
          else
            num = nil
            existing_vers.each_with_index do |line, i|
              curr_urn = line[:version][/#{vers_urn_wo_num}\d+/]
              urn_num = curr_urn[/\d+$/].to_i
              num = urn_num + 1
              if line[:label_eng] =~ /#{vers_label}/ && line[:desc_eng] =~ /#{vers_desc}/
                #this means that the pulled label and description match the current row, not good?
              end
            end
            vers_urn = "#{vers_urn_wo_num}#{num}"
          end
          #need to check that the description isn't the same
            #how to determine if it is a second mods record for an edition?
            #oclc #s and LCCNs?
          #insert row in table
          vers_cite = Version.generate_urn
          puts "got cite urn #{vers_cite}"
          v_values = ["#{vers_cite}", "#{vers_urn}", "#{vers_label}", "#{vers_desc}", "#{vers_type}", 'true', 'test','','','auto_importer', 'auto_importer']
          #this is to test the tables
          Version.add_cite_row(v_values)
  
          #add cts urn to record
          id_line = mods_xml.search("/mods:mods/mods:identifier").last
          n_id = Nokogiri::XML::Node.new "mods:identifier", mods_xml
          n_id.add_namespace_definition("mods", "http://www.loc.gov/mods/v3")
          n_id.content = vers_urn
          n_id.set_attribute("type", "ctsurn")
          id_line.add_next_sibling(n_id)

          
          modspath = create_mods_path(vers_urn)
          move_file(modspath, mods_xml)
          #then save at new location and remove from old
        end
      
      
    rescue
      message = "For file #{info_hash[:file_name]} : There was an error while trying to save the version, error message was: #{$!}."
      error_handler(message, info_hash[:path], info_hash[:file_name])
    end
  end

  def split_constituents(mods_xml, file_path)
    #need to create a new mods file for each constituent item
    #take each <relatedItem type="constituent"> and make it the top level in a new mods record
    #use builder to create mods level, then going to have to use .each to add the children of relatedItem
    #add the top level info for the original wrapped as <relatedItem type="host">
    #save new files to catalog pending
 
    const_nodes = mods_xml.search("//mods:relatedItem[@type='constituent']")
    const_nodes.each do |const|
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
      add_to_cite_tables(info_hash, builder.doc) if info_hash
      add_to_vers_table(info_hash, builder.doc) if info_hash
    end
  end

  def fusion_tables_update
  end

end