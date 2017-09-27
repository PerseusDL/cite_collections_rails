#Copyright 2013 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

module CiteColls
  require 'nokogiri'
  require 'mechanize'


  def set_agent(a_alias = 'Mac Safari')
    @agent = Mechanize.new
    @agent.user_agent_alias= a_alias
    return @agent
  end



  def update_git_dir(dir_name)
    start_time = Time.now
    data_dir = "#{BASE_DIR}/#{dir_name}"
    unless File.directory?(data_dir)
      `git clone https://github.com/PerseusDL/#{dir_name}.git $HOME/#{dir_name}`
    end
    
    if File.mtime(data_dir) < start_time
      puts "Pulling the latest files from the #{dir_name} GitHub directory"
      `git --git-dir=#{data_dir}/.git --work-tree=#{data_dir} pull`
    end

  end


  def multi_agents
    #this and agent_rotate is my tricky way to get around google fusion api's user limits...
    @agent_arr = []
    @agent_arr << set_agent
    @agent_arr << set_agent('Windows Mozilla')
    @agent_arr << set_agent('Linux Firefox')
    @agent_arr << set_agent('Mac Mozilla')
    @agent_arr << set_agent('Windows IE 9')
  end


  def multi_get(url)
    page = @agent_arr[0].get(url)
    new_first = @agent_arr.pop(1)
    @agent_arr = new_first.concat(@agent_arr)
    return page
  end



  def inc_urn(last_urn, code)
    count = last_urn.split(".")[1].to_i + 1
    new_urn = "urn:cite:perseus:#{code}.#{count.to_s}.1"
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
          unless cite_auth_id == info_hash[:canon_id] || cite_auth.alt_ids.include?(info_hash[:canon_id])
            message = "For file #{info_hash[:file_name]}: The author id saved in the CITE table doesn't match the id in the file, please check."
            error_handler(message, true)
            return
          end
        end
        Author.update_row(info_hash, "auto_importer") unless mods_xml
      end

      unless info_hash[:cite_tg]
        if info_hash[:a_name]
          if info_hash[:tg_id]
            #no row for this textgroup, add a row
            t_urn = Textgroup.generate_urn
            t_values = ["#{t_urn}", "#{info_hash[:tg_id]}", "#{info_hash[:a_name]}", "#{info_hash[:cite_auth] != []}", 'true','', 'published', '', 'auto_importer','']
            Textgroup.add_cite_row(t_values)
          else
            #!!This will need to change once we establish how to coin urns for these sorts of authors
            message = "LCCN id found in record, this is probably an editor, can not create textgroup"
            error_handler(message, false)
            return
          end
        else
          message = "No author name found in record, can not create textgroup"
          error_handler(message, false)
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
          w_values = [w_urn, info_hash[:w_id], info_hash[:w_title], info_hash[:w_lang], '', 'published', '', 'auto_importer','']
          Work.add_cite_row(w_values)
          #check that the work is listed in Author.related_works, if not, add it 
          cite_auth_arr.each do |cite_auth|
            w_o_cts = info_hash[:w_id][/\w+\.\w+$/]
            s_rel_w = cite_auth.related_works
            unless s_rel_w =~ /#{w_o_cts}/
              if (s_rel_w == nil || s_rel_w.empty?) 
                rel_w = w_o_cts 
              else
                rel_w = "#{s_rel_w};#{w_o_cts}"
              end
              Author.update(cite_auth.id, {:related_works => rel_w})
            end
          end
          puts "added work"
        else
          # We don't want to just blindly update the work row if it exists already 
          # there might be some cases where we want to but we need a way to explicit about that otherwise
          # we get a bunch of garbage
          #Work.update_row(info_hash, "auto_importer")
        end

      end

    rescue Exception => e
      if e.message
        message = "#{e.message}, #{e.backtrace}"
      else
        message = "For file #{info_hash[:file_name]}: something went wrong, #{$!}"
      end
      error_handler(message, true)
      return
    end
  end


  def add_to_vers_table(info_hash, mods_xml, cts_urn=nil, range_string="", full_record="")
    begin      
      #vers_col = "urn, version, label_eng, desc_eng, type, has_mods, urn_status, redirect_to, member_of, created_by, edited_by"           
      #two (or more) languages listed, create more records
      vers_urns = []
      info_hash[:v_langs].each do |lang|
        vers_label, vers_desc = create_label_desc(mods_xml)
        full_label = info_hash[:w_title] + ", " + vers_label
        full_label = full_label + ";" + range_string if range_string != ""
        vers_urn = ""
        vers_type = lang == info_hash[:w_lang] ? "edition" : "translation"
        unless cts_urn
          #is it a Perseus edition?
          pers_ed = false
          mods_xml.search("//mods:identifier",ApplicationHelper::MODS_NS).each {|node| pers_ed = true if (node.inner_text =~ /Perseus:text/ || node.inner_text =~ /cts:.+perseus-/)}
          coll = pers_ed ? "perseus" : "opp"
          
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
            end
            vers_urn = "#{vers_urn_wo_num}#{num}"
          end
        else
          vers_urn = cts_urn
        end
        #insert row in table
        vers_cite = Version.generate_urn
        puts "got cite urn #{vers_cite} for #{vers_urn}"
        v_values = ["#{vers_cite}", "#{vers_urn}", "#{full_label}", "#{vers_desc}", "#{vers_type}", 'true', 'published','','','auto_importer', '']
        # let's be sure it isn't otherwise an exact match 
        dups = Version.has_match(v_values)
        if dups.size > 0
          message = "For file #{info_hash[:file_name]} : there was a matching version for language #{lang}: #{dups.join(',')}. A new record will not be added."
          # we will not make this a fatal error because we might be reprocessing a mods record containing multiple language versions
          error_handler(message, false)
        else 
          Version.add_cite_row(v_values)
          vers_urns << vers_urn
        end
      end
      return vers_urns
    rescue Exception => e
      message = "For file #{info_hash[:file_name]} : There was an error while trying to save the version, error message was: #{$!}. \n\n #{e.backtrace}"
      error_handler(message, true)
    end
  end

  def add_cts_urn(mods_xml, vers_urn)
    #add cts urn to record
    id_line = mods_xml.search("/mods:mods/mods:identifier",ApplicationHelper::MODS_NS).last
    id_line = mods_xml.search("./mods:identifier",ApplicationHelper::MODS_NS).last if id_line == nil
    #there can only be one ctsurn in a record (this is really for creating records with facing translations)
    if id_line.attribute("type").value == "ctsurn"
      id_line.content = vers_urn
    else
      n_id = Nokogiri::XML::Node.new "identifier", mods_xml
      n_id.add_namespace_definition(nil,"http://www.loc.gov/mods/v3")
      n_id.content = vers_urn
      n_id.set_attribute("type", "ctsurn")
      id_line.add_next_sibling(n_id)
    end
  end

end
