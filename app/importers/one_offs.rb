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
          w_list = works.join(';')
          unless w_list == auth.related_works
            auth.related_works = w_list
            auth.edited_by = "related_work_finder"
            auth.save
          end
        rescue
          puts "Error for #{auth.urn}, #{$!}"
        end
      end
    end 
  end

end