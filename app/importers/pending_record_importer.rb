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
    pending_mads = "#{BASE_DIR}/catalog_pending/mads"
    pending_mods = "#{BASE_DIR}/catalog_pending/mods"
    corrections = "#{BASE_DIR}/catalog_data"

    #update_git_dir("catalog_pending") UNCOMMENT THIS
    update_from_catalog_data(corrections)
    mads_import(pending_mads)
    mods_import(pending_mods)

    #remove all the now empty directories, leaving only the files that encountered errors
    Dir["#{pending_mads}/**/"].reverse_each { |d| Dir.rmdir d if Dir.entries(d).size == 2 }
    Dir["#{pending_mods}/**/"].reverse_each { |d| Dir.rmdir d if Dir.entries(d).size == 2 }
  end

  def mads_import(pending_mads)
    all_mads_dirs = clean_dirs(pending_mads)
    mads_files = []
    all_mads_dirs.each {|file| mads_files << file unless file =~ /marc/}
    mads_files.each do |mads|
      mads_xml = get_xml(mads)
      info_hash = find_basic_info(mads_xml, mads)
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
          move_file(madspath, mads_xml)
          #remove the successfully imported file from catalog_pending
          FileUtils.rm(mads)
        end
      else
        message = "For file #{mads} : No info hash returned, something has gone wrong, please check."
        error_handler(message, mads, mads)
      end
    end
    #remove all the marc records
    FileUtils.rm Dir.glob("#{pending_mads}/**/*.marcxml.xml")
  end

  def mods_import(pending_mods)
    mods_files = clean_dirs(pending_mods)
    mods_files.each do |mods|
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
            #has cite row, lacking a mods, update accordingly 
            Version.update(v_obj.id, {:has_mods => "true", :edited_by => "auto_importer"})
            info_hash = find_basic_info(mods_xml, mods)
            Version.update_row(ctsurn, info_hash, mods, "auto_importer")
          end
          #if has row and confirmed mods, not a correction, assumed multivolume, just move to correct place
          Version.update_row(ctsurn, info_hash, mods, "auto_importer")
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
              #remove the successfully imported file from catalog_pending
              FileUtils.rm(file_path) 
          else
            message = "For file #{file_path} : No info hash returned, something has gone wrong, please check. #{$!}"
            error_handler(message, file_path, file_path)
          end
        end
      end
    end
  end

  def add_to_cite_tables(info_hash, mods_xml=nil)
    begin
      #cite table columns are...
      #auth_col = "urn, authority_name, canonical_id, mads_file, alt_ids, related_works, urn_status, redirect_to, created_by, edited_by"
      #tg_col = "urn, textgroup, groupname_eng, has_mads, mads_possible, notes, urn_status, redirect_to, created_by, edited_by"
      #work_col = "urn, work, title_eng, notes, urn_status, redirect_to, created_by, edited_by"

      #reminder! there can be more than one author, so authors are handled in arrays
      cite_auth_arr = info_hash[:cite_auth]

      if cite_auth_arr.empty?
        #no row for this author, add a row       
        unless mods_xml
          #only creates rows in the authors table for mads files, so authors acts as an index of our mads, 
          #tgs can cover everyone mentioned in mods files
          a_urn = Author.generate_urn
          mads_path = create_mads_path(info_hash[:path])[/PrimaryAuthors.+\.xml/]         
          a_values = ["#{a_urn}", "#{info_hash[:a_name]}", "#{info_hash[:canon_id]}", "#{mads_path}", "#{info_hash[:alt_ids]}", "#{info_hash[:related_works]}", 'published','', 'auto_importer', '']
          info_hash[:cite_auth] << Author.add_cite_row(a_values)
        end
        
      else
        cite_auth_arr.each do |cite_auth|
          #find name returned from cite tables, compare to name from record
          #if they aren't equal, throw an error
          cite_name = cite_auth.authority_name
          cite_auth_id = cite_auth.canonical_id 
          unless cite_auth_id == info_hash[:canon_id] || info_hash[:canon_id] =~ /#{cite_auth.alt_ids}/
            message = "For file #{info_hash[:file_name]}: The author id saved in the CITE table doesn't match the id in the file, please check."
            error_handler(message, info_hash[:path], info_hash[:file_name])
            return
          end
        end
        Author.update_row(info_hash, "auto_importer") unless mods_xml
      end

      unless info_hash[:cite_tg]
        if info_hash[:a_name]
          if info_hash[:a_id]
            #no row for this textgroup, add a row
            t_urn = Textgroup.generate_urn
            t_values = ["#{t_urn}", "#{info_hash[:a_id]}", "#{info_hash[:a_name]}", "#{info_hash[:cite_auth] == nil}", 'true','', 'published', '', 'auto_importer','']
            Textgroup.add_cite_row(t_values)
          else
            #!!This will need to change once we establish how to coin urns for these sorts of authors
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
            Textgroup.update(tg.id, {:has_mads => 'true', :edited_by => "auto_importer"})
          end
        end
      end
      if mods_xml
        unless info_hash[:cite_work]
          #no row for this work, add a row
          w_urn = Work.generate_urn
          w_values = [w_urn, info_hash[:w_id], info_hash[:w_title], info_hash[:orig_lang], '', 'published', '', 'auto_importer','']
          Work.add_cite_row(w_values)
          #check that the work is listed in Author.related_works, if not, add it 
          cite_auth_arr.each do |cite_auth|
            w_o_cts = info_hash[:w_id][/\w+\.\w+$/]
            s_rel_w = cite_auth.related_works
            unless s_rel_w =~ /#{w_o_cts}/
              rel_w = (s_rel_w == nil || s_rel_w.empty?) ? w_o_cts : (s_rel_w << ";#{w_o_cts}")
              Author.update(cite_auth.id, {:related_works => rel_w})
            end
          end
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
              message = "#{curr_urn} and #{vers_urn_wo_num} have the same label and description, please check!"
              error_handler(message, info_hash[:path], info_hash[:file_name])
              return
            end
          end
          vers_urn = "#{vers_urn_wo_num}#{num}"
        end

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
    #remove the successfully imported file from catalog_pending
    FileUtils.rm(file_path)
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
        if message =~ /Update/ #!!assuming one commit = one file  BAD ASSUMPTION
          parts = message.split(/\s/)
          file = parts[1] if parts[1] =~ /\.xml/
          file_path = Dir.glob("#{path}/**/#{file}")[0]
          mods_xml = get_xml(file_path)

          info_hash = find_basic_info(mods_xml, file_path)
          if info_hash
            if file_path =~ /mads/              
              Author.update_row(info_hash, editor)
            else
              Textgroup.update_row(info_hash, editor)             
              Work.update_row(info_hash, editor)

              cts = file_path[/\w+\.\w+\.\w+-\w+\d+/]
              vers_label, vers_desc = create_label_desc(mods_xml)
              Version.update_row(cts, vers_label, vers_desc, editor)
            end
          end
        end
      rescue
        message = "Error for catalog_data update, commit was #{commit["sha"]}, error message was: #{$!}"
        error_handler(message)
      end
    end
  end


end