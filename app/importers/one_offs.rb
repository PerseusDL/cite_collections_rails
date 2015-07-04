class OneOffs
  include ApplicationHelper

  def mads_path_change
    #updates the mads path and adds a cite id if needed
    mads_files = Dir["#{BASE_DIR}/catalog_data/mads/PrimaryAuthors/**/*{mads,madsxml}.xml"]
    mads_files.each do |file|
      file_xml = get_xml(file)
      cite = file_xml.search('//mads:identifier[@type="citeurn"]').inner_text
      a_row = Author.find_by_urn(cite)
      unless a_row
        id, alt_ids = find_rec_id(file_xml, file, file)
        if id
          a_row = Author.find_by_canonical_id(id)
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


  def mads_rel_works
    auths = Author.all
    auths.each do |auth|
      if auth.urn_status == "published"
        works = []
        mads_xml = get_xml("#{BASE_DIR}/catalog_data/mads/#{auth.mads_file}")
        ns = mads_xml.collect_namespaces
        rel_works_nodes = mads_xml.xpath("//mads:extension/identifier", ns)
        unless rel_works_nodes.empty?
          begin
            rel_works_nodes.each do |node|
              if node.attribute("type")
                id = clean_id(node)
                works << id
              else
                puts "Error for #{auth.urn}, no type for rel work id in MADS"
                next
              end
            end
            rw_list = auth.related_works.split(';')
            works.delete_if {|w| rw_list.include?(w)}
            rw_list.concat(works)
            auth.related_works = rw_list.join(';')
            auth.edited_by = "related_work_finder"
            auth.save
            
          rescue
            puts "Error for #{auth.urn}, #{$!}"
          end
        end
      end
    end 
  end


  def catalog_data_double_check(file_path)
    begin
      @error_report = File.open("#{BASE_DIR}/catalog_pending/errors/error_log#{Date.today}.txt", 'w')
      editor = "double_check"
      xml = get_xml(file_path)
      if file_path =~ /mods/
        namespaces = xml.namespaces
        unless namespaces.include?("xmlns:mods")
          add_mods_prefix(xml)
          File.open(file_path, "w"){|file| file << xml}
          new_xml = get_xml(file_path)
          it_worked = new_xml.search("/mods:mods/mods:titleInfo")
          if it_worked == nil || it_worked.empty?
            message = "For file #{file_path}: tried adding prefix to mods but something went wrong, please check"
            error_handler(message, true)
            
          else
            xml = new_xml
          end
        end
      end

      info_hash = find_basic_info(xml, file_path)
      if info_hash
        if file_path =~ /mads/ 
          if info_hash[:cite_auth].empty?
            a_urn = Author.generate_urn
            mads_path = create_mads_path(info_hash[:path])[/PrimaryAuthors.+\.xml/]         
            a_values = ["#{a_urn}", "#{info_hash[:a_name]}", "#{info_hash[:canon_id]}", "#{mads_path}", "#{info_hash[:alt_ids]}", "#{info_hash[:related_works]}", 'published','', 'auto_importer', '']
            info_hash[:cite_auth] << Author.add_cite_row(a_values)    
          else        
            Author.update_row(info_hash, editor)
          end
        else
          unless info_hash[:cite_tg]
            if info_hash[:a_name]
              if info_hash[:tg_id]
                #no row for this textgroup, add a row
                t_urn = Textgroup.generate_urn
                t_values = ["#{t_urn}", "#{info_hash[:tg_id]}", "#{info_hash[:a_name]}", "#{info_hash[:cite_auth] == nil}", 'true','', 'published', '', 'auto_importer','']
                Textgroup.add_cite_row(t_values)
              else
                #!!This will need to change once we establish how to coin urns for these sorts of authors
                message = "LCCN id found in record, this is probably an editor, can not create textgroup"
                error_handler(message, true)
                return
              end
            else
              message = "No author name found in record, can not create textgroup"
              error_handler(message, true)
              return
            end
          else
            Textgroup.update_row(info_hash, editor)  
          end  
          unless info_hash[:cite_work]
            #no row for this work, add a row
            w_urn = Work.generate_urn
            w_values = [w_urn, info_hash[:w_id], info_hash[:w_title], info_hash[:orig_lang], '', 'published', '', 'auto_importer','']
            Work.add_cite_row(w_values)
            #check that the work is listed in Author.related_works, if not, add it 
            info_hash[:cite_auth].each do |cite_auth|
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
          else         
            Work.update_row(info_hash, editor)
          end

          cts = file_path[/\w+\.\w+\.\w+-\w+\d+/]
          vers_label, vers_desc = create_label_desc(xml)
          v_label = info_hash[:w_title] + ", " + vers_label
          Version.update_row(cts, v_label, vers_desc, editor)
        end
      end
    rescue Exception => e
      message = "for #{file_path}, #{$!}\n#{e}"
      puts message
    end
  end


  def work_title_correction
    work_files = Dir.glob("#{BASE_DIR}/catalog_data/mods/**/*.xml")
    work_files.each do |file_name|
      begin
        mods_xml = get_xml(file_name)
        has_cts = mods_xml.search("/mods:mods/mods:identifier[@type='ctsurn']")
        if has_cts
          ctsurn = has_cts.inner_text
          info_hash = find_basic_info(mods_xml, file_name, ctsurn)
          work = info_hash[:cite_work]
          unless work.title_eng == info_hash[:w_title]
            work.title_eng = info_hash[:w_title]
            work.edited_by = "title_corrector"
            work.save
          end

          vers_arr = Version.find(:all, :conditions => ["version = ? and urn_status = 'published'", ctsurn])
          if vers_arr.length == 1
            vers = vers_arr[0]
          else
            puts "Either more than one or no versions returned for #{ctsurn} in #{file_name}"
            next
          end
          label, description = create_label_desc(mods_xml)
          full_label = work.title_eng + ", " + label
          unless vers.label_eng == full_label
            vers.label_eng = full_label
            vers.edited_by = "title_corrector"
            vers.save
          end
          unless vers.desc_eng == description
            vers.desc_eng = description
            vers.edited_by = "title_corrector"
            vers.save
          end
        else
          puts "Error, no cts urn for #{file_name}"
        end

      rescue
        puts "Error, #{$!}"
      end
    end

  end


  def match_old_auth_ids
    file = File.open("#{BASE_DIR}/dumps/old_auth.csv", "r").read
    output = File.new("#{BASE_DIR}/dumps/old_auth_matches.csv", "w")
    rows = file.split("\n")
    rows.each do |row|
      row_arr = row.split(/,/)
      old_id = row_arr[0]
      main_id = old_id[/(phi|tlg|stoa)\d+[a-z]?/]
      if old_id =~ /^M/
        auth_arr = Author.get_by_id(main_id)
        if auth_arr.length == 1
          auth = auth_arr[0]
        else
          if auth_arr.empty?
            puts "got nothing for #{main_id} in Authors table"
            next
          else
            auth_arr.each do |auth_row|
              if row_arr[1] =~ /#{auth_row.urn}/
                auth = auth_row
                break
              end
            end
          end
          
        end
      elsif old_id =~ /^A/
        auth_arr = Author.get_by_id(main_id)
        if auth_arr.empty?
          auth_arr = Textgroup.find(:all, :conditions => ["textgroup rlike ? and has_mads = 'false'", main_id])
        end
        if auth_arr.length == 1
          auth = auth_arr[0]
        else
          if auth_arr.empty?
            puts "got nothing for #{main_id} in Textgroup table"
            next
          else
            auth_arr.each do |auth_row|
              if row_arr[1] =~ /#{auth_row.urn}/
                auth = auth_row
                break
              end
            end
          end  
        end
      else
        puts "Something is wrong with #{row}"
        next
      end
      match_string = old_id + "," + auth.urn + "\n"
      output << match_string
    end
    output.close      
  end


  def fix_mrurns(path)
    xml = get_xml(path)
    if path =~ /\.mods\.xml/
      ns = xml.collect_namespaces
      mrurns = xml.search("//mods:identifier[@type='mrurn']", ns)
      unless mrurns.empty?
        fixed = mrurns[0].inner_text.gsub(/#|_\d+/, "")
        fix_arr = fixed.split('.')
        fixed_again = fix_arr[0] + fix_arr[1] + "." + fix_arr[2]
        mrurns[0].content = fixed_again
        file = File.open(path, "w")
        file << xml
        file.close
      end
    else
      mrurns = xml.search("//mads:identifier[@type='mrurn']")
      unless mrurns.empty?
        fixed = mrurns[0].inner_text.gsub(/#|\./, "")
        mrurns[0].content = fixed
        file = File.open(path, "w")
        file << xml
        file.close
      end
    end

  end

end