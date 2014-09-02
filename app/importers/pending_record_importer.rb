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
    @error_report = File.open("#{ENV['HOME']}/catalog_pending/errors/error_log#{Date.today}.txt", 'w')
    pending_mads = "#{ENV['HOME']}/catalog_pending/mads"
    pending_mods = "#{ENV['HOME']}/catalog_pending/mods"
    corrections = "#{ENV['HOME']}/catalog_data"

    #update_git_dir("catalog_pending") UNCOMMENT THIS
    update_from_catalog_data(corrections)
    mads_import(pending_mads)
    mods_import(pending_mods)

    #fusion_tables_update
  end

  def mads_import(pending_mads)
    mads_dirs = clean_dirs(pending_mads)
    mads_dirs.each do |name_dir|
      mads = clean_dirs(name_dir).select { |f| f =~ /mads/}[0]
      if mads
        mads_xml = get_xml(mads)
        info_hash = find_basic_info(mads_xml, mads)
        #if it already exists we don't need to add it to the table again!
        if info_hash
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
        #`rm #{file_path}`
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
    #also add commit and push of changes to catalog_pending and catalog_data
  end

  def add_to_cite_tables(info_hash, mods_xml=nil)
    begin
      #cite table columns are...
      #auth_col = "urn, authority_name, canonical_id, mads_file, alt_ids, related_works, urn_status, redirect_to, created_by, edited_by"
      #tg_col = "urn, textgroup, groupname_eng, has_mads, mads_possible, notes, urn_status, redirect_to, created_by, edited_by"
      #work_col = "urn, work, title_eng, notes, urn_status, redirect_to, created_by, edited_by"

      unless info_hash[:cite_auth]

        #no row for this author, add a row       
        unless mods_xml
          #only creates rows in the authors table for mads files, so authors acts as an index of our mads, 
          #tgs can cover everyone mentioned in mods files
          a_urn = Author.generate_urn
          mads_path = create_mads_path(info_hash[:path])[/PrimaryAuthors.+\.xml/]         
          a_values = ["#{a_urn}", "#{info_hash[:a_name]}", "#{info_hash[:canon_id]}", "#{mads_path}", "#{info_hash[:alt_ids]}", "#{info_hash[:related_works]}", 'published','', 'auto_importer', '']
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
        if info_hash[:a_name]
          if info_hash[:a_id]
            #no row for this textgroup, add a row
            t_urn = Textgroup.generate_urn
            t_values = ["#{t_urn}", "#{info_hash[:a_id]}", "#{info_hash[:a_name]}", "#{info_hash[:cite_auth] == nil}", 'true','', 'published', '', 'auto_importer','']
            Textgroup.add_cite_row(t_values)
          else
            message = "LCCN id found in record, this is probably an editor, can not create textgroup"
            error_handler(message, info_hash[:path], info_hash[:file_name])
            return
          end
        else
          message = "No author name found in record, can not create textgroup"
          error_handler(message, info_hash[:path], info_hash[:file_name])
          return
        end
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
          w_values = [w_urn, info_hash[:w_id], info_hash[:w_title], info_hash[:orig_lang], '', 'published', '', 'auto_importer','']
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
        vers_label, vers_desc = create_label_desc(mods_xml)
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
        v_values = ["#{vers_cite}", "#{vers_urn}", "#{vers_label}", "#{vers_desc}", "#{vers_type}", 'true', 'published','','','auto_importer', '']
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
      end     
    rescue
      message = "For file #{info_hash[:file_name]} : There was an error while trying to save the version, error message was: #{$!}."
      error_handler(message, info_hash[:path], info_hash[:file_name])
    end
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
        add_to_cite_tables(info_hash, builder.doc)
        add_to_vers_table(info_hash, builder.doc)
      else
        new_path = file_path.chomp(".xml") + "const#{i}.xml"
        move_file(new_path, builder.doc)
        new_name = new_path[/(\/[a-zA-Z0-9\s\.\(\)-]+)?\.xml/]
        message = "For file #{new_path}: no info_hash returned, saving new constituent record in errors"
        error_handler(message, new_path, new_name)
      end
    end
  end


  def update_from_catalog_data(path)
    today = Time.now
    #first time running this the time needs to be from the beginning of edits to catalog_data
    #first time from July 9, 2013
    #after that, need a set time, will we run this as a chron job?
    since = "2013-07-08T00:00:00Z" #(today - seconds).to_s
    url = "https://api.github.com/repos/PerseusDL/catalog_data/commits?since=#{since}"
    agent = Mechanize.new
    gh_results = agent.get(url)
    json = JSON.parse(gh_results.body)
    json.each do |commit|
      #working with a hash of hashes
      
      message = commit["commit"]["message"]
      editor = commit["commit"]["author"]["name"]
      begin
        if message =~ /Update/ #assuming one commit = one file  BAD ASSUMPTION
          parts = message.split(/\s/)
          file = parts[1] if parts[1] =~ /\.xml/
          file_path = Dir.glob("#{path}/**/#{file}")[0]
          mods_xml = get_xml(file_path)
          info_hash = find_basic_info(mods_xml, file_path)
          if info_hash
            if file_path =~ /mads/
              auth = info_hash[:cite_auth]
              auth_hash = {}           
              auth_hash[:authority_name] = info_hash[:a_name] if auth.authority_name != info_hash[:a_name]
              auth_hash[:alt_ids] = info_hash[:alt_ids] if auth.alt_ids != info_hash[:alt_ids]
              auth_hash[:related_works] = info_hash[:related_works] if auth.related_works != info_hash[:related_works]
    
              unless auth_hash.empty?
                auth_hash[:edited_by] = editor
                Author.update_row(auth.id, auth_hash)
              end
            else
              cts = file_path[/\w+\.\w+\.\w+-\w+\d+/]
              tg_hash, w_hash, v_hash = {}, {}, {}
              tg = info_hash[:cite_tg]
              work = info_hash[:cite_work]
              vers = Version.find_by_cts(cts)[0]

              if tg.groupname_eng != info_hash[:a_name]
                tg_hash[:groupname_eng] = info_hash[:a_name]
                tg_hash[:edited_by] = editor
                Textgroup.update_row(tg.id, tg_hash)
              end

              if work.title_eng != info_hash[:w_title]
                w_hash[:title_eng] = info_hash[:w_title]
                w_hash[:edited_by] = editor
                Work.update_row(work.id, w_hash)
              end

              vers_label, vers_desc = create_label_desc(mods_xml)            
              v_hash[:label_eng] = vers_label if vers.label_eng != vers_label
              v_hash[:desc_eng] = vers_desc if vers.desc_eng != vers_desc
              unless v_hash.empty?
                v_hash[:edited_by] = editor
                Version.update_row(vers.id, v_hash)
              end

            end
          end
        end
      rescue
        message = "Error for catalog_data update, commit was #{commit["sha"]}, error message was: #{$!}"
        error_handler(message)
      end
    end
  end

  def mads_path_change
  
    mads_files = Dir["#{ENV['HOME']}/catalog_data/mads/PrimaryAuthors/**/*{mads,madsxml}.xml"]
    mads_files.each do |file|
      file_xml = get_xml(file)
      cite = file_xml.search('//mads:identifier[@type="citeurn"]').inner_text
      a_row = Author.find_by_urn(cite)
      unless a_row
        id, alt_ids = find_rec_id(file_xml, file, file)
        if id
          a_row = Author.find_by_id(id)
          if a_row
            id_line = file_xml.search("/mads:mads/mads:identifier").last
            n_id = Nokogiri::XML::Node.new "mads:identifier", file_xml
            n_id.add_namespace_definition("mads", "http://www.loc.gov/mads/v2")
            n_id.content = a_row.urn
            n_id.set_attribute("type", "citeurn")
            id_line.add_next_sibling(n_id)
            m_file = File.open(file, 'w')
            m_file << file_xml
            m_file.close
          else
            puts "error with #{file}, check for urns"
            next
          end
        end
      end
      unless a_row.mads_file == file[/PrimaryAuthors.+/]
        a_row.mads_file = file[/PrimaryAuthors.+/]
        a_row.save
      end
    end
  end

  def fusion_tables_update
  end

end