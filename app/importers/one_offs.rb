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
      editor = "auto_import"
      xml = get_xml(file_path)
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
          Version.update_row(cts, vers_label, vers_desc, editor)
        end
      end
    rescue Exception => e
      message = "for #{file_path}, #{$!}\n#{e}"
      puts message
    end
  end

end