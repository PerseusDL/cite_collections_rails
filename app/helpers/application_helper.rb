#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

module ApplicationHelper

  #Helper methods


#create directory path
  def create_mods_path(ctsurn)  
    path_name = "#{ENV['HOME']}/catalog_pending/test/mods/"
    ctsmain = ctsurn[/(greekLit|latinLit).+/]
    path_name << "#{ctsmain.gsub(/:|\./, "/")}"
    unless File.exists?(path_name)
      FileUtils.mkdir_p(path_name)
    end
    if File.exists?(path_name)
      Dir.chdir(path_name)
      sansgl = ctsmain.gsub(/greekLit:|latinLit:/, "")
      mods = Dir["#{sansgl}.*"]
      mods_num = 0
      mods.each {|x| mods_num = mods_num < x[/\d+\.xml/].chr.to_i ? x[/\d+\.xml/].chr.to_i : mods_num}
      modspath = "#{path_name}/#{sansgl}.mods#{mods_num + 1}.xml"
    end
    return modspath
  end  

  def create_mads_path(old_path)
    path_name = "#{ENV['HOME']}/catalog_pending/mads/PrimaryAuthors/"
    op_parts = old_path.split("/")
    file_n = op_parts.pop
    name = op_parts.pop
    frst_let = name[0]   
    path_name << "#{frst_let}/#{name}/"
    unless File.exists?(path_name)
      FileUtils.mkdir_p(path_name)
    end
    path_name << file_n
  end

  def move_file(path, xml)
    fl = File.open(path, "w")
    fl << xml
    fl.close
  end

#find things in the XML

  def find_basic_info(xml_record, file_path)
    begin
      #a regex ugly enough that only its mother could love it, 
      #all to get a file name that I had earlier but cleverly turned into the path that I needed then...
      f_n = file_path[/(\/[a-zA-Z0-9\s\.\(\)-]+)?\.xml/]
      id, alt_ids = find_rec_id(xml_record, file_path, f_n)
      unless id =~ /lccn/i
        lit_type = id =~ /tlg/ ? "greek" : "latin"
        lit_abbr = lit_type == "greek" ? "grc" : "lat"
        #for mads the w_id and a_id will be the same
        w_id = id =~ /cts/ ? id[/urn:cts:\w+:\w+\d+[a-z]*\.\w+\d+[a-z0-9]*/] : "urn:cts:#{lit_type}Lit:#{id}"
        if f_n =~ /mads/ && id =~ /cts/
          a_id = id
        else
          a_id = w_id[/urn:cts:\w+:\w+\d+[a-z]*/]
        end
        canon_id = a_id[/\w+\d+[a-z]*$/]
      else
        a_id = nil
        canon_id = id
      end
      if id
        #search for and compare author values
        auth_name = find_rec_author(xml_record, file_path, f_n)
        auth_nset = Author.find_by_id(canon_id)      
        tg_nset = Textgroup.find_by_id(a_id)   
        
        info_hash = { :file_name => f_n,
                      :path => file_path,
                      :canon_id => canon_id,
                      :a_name => auth_name,
                      :a_id => a_id,
                      :alt_ids => alt_ids,
                      :cite_auth => auth_nset,
                      :cite_tg => tg_nset}

        if f_n =~ /mods/
          work_title = nil
          xml_record.search("/mods:mods/mods:titleInfo").each do |title_node|
            #take uniform if it exists
            type = title_node.attribute("type")
            if type && type.value == "uniform"
              work_title = title_node.search("./mods:title").inner_text
            end
            unless work_title && type
              work_title = title_node.search("./mods:title").inner_text
            end
            unless work_title
              work_title = title_node.search("./mods:title").inner_text
            end
          end

          work_row = Work.find_by_id(w_id)        
          orig_lang = work_row ? work_row.orig_lang : lit_abbr
          vers_langs = []
          xml_record.search("/mods:mods/mods:relatedItem/mods:language").each do |x|
            attri = x.attribute("objectPart")
            #want to only get text language when the designation is there, as opposed to the preface
            if attri
              vers_langs << x.inner_text if attri.value == "text"
            else
              #but not all records have a type="text" and we need that language anyway
              vers_langs << x.inner_text
            end
          end
          info_hash.merge!(:w_title => work_title,
                        :w_id => w_id,
                        :cite_work => work_row,
                        :w_lang => orig_lang,
                        :v_langs => vers_langs)
        else
          #related works, find <mads:description>List of related work identifiers and grab siblings
          extensions = xml_record.search("/mads:mads/mads:extension/mads:description")
          extensions.each do |ex|
            if ex.inner_text == "List of related work identifiers"
              related_works = []
              ex.parent.children.each {|x| related_works << clean_id(x) if x.name == "identifier"}
              info_hash.merge!(:related_works => related_works.join(';'))
              break
            end
          end
        end
        
        return info_hash       
      end
    rescue Exception => e
      file_name = file_path[/(\/[a-zA-Z0-9\.\(\)]+)?\.xml/]
      message = "For file #{file_name}: something went wrong, #{$!} #{e.backtrace}"
      error_handler(message, file_path, file_name)
      return nil
    end
  end

  def find_rec_author(xml_record, file_path, f_n)
    begin
      #grab mads authority name
      if f_n =~ /mads/ 
        name_ns = xml_record.search("/mads:mads/mads:authority/mads:name/mads:namePart")
        n = [] 
        unless name_ns.empty?
          name_ns.each {|x| n << x.inner_text}
          a_name = n.join(" ")
        else
          message = "For file #{f_n} : Could not find an authority name, please check the record."
          error_handler(message, file_path, f_n)
          return
        end
      else   

      #grab the name with the "creator" role      
        names = {}
     
        name_ns = xml_record.search("/mods:mods/mods:name")
        unless name_ns.empty?
          name_ns.each do |node|
            a_type = node.search("./mods:role/mods:roleTerm").inner_text
            if a_type =~ /creator$|author/
              n = []
              node.search("./mods:namePart").each {|x| n << x.inner_text}
              names[a_type] = n.join(" ")             
            end
          end
          if names.empty?
            message = "For file #{f_n} : Could not find an author name, please check the record."
            error_handler(message, file_path, f_n)
            return
          else
            if names.size == 1
              a_name = names.values[0] 
            else
              a_name = names["creator"] ? names["creator"] : names.values[0]
            end 
          end
        else
          message = "For file #{f_n} : Could not find an author name, please check the record."
          error_handler(message, file_path, f_n)
          return
        end
      end
      return a_name
    rescue
      message = "For file #{f_n} : There was an error while trying to find the author, error message was #{$!}."
      error_handler(message, file_path, f_n)
    end
  end


  def find_rec_id(xml_record, file_path, f_n)

    begin
      ids = f_n =~ /mads/ ? xml_record.search("/mads:mads/mads:identifier") : xml_record.search("/mods:mods/mods:identifier")
      found_id = nil
      alt_ids = []

      #parsing found ids, take tlg or phi over stoa unless there is an empty string or "none"
      ids.each do |node|
        if file_path =~ /euphorion.FHG3.Fragmenta.mods/
          byebug
        end
        id = clean_id(node)
        
        unless id == "none" || id == "" || id =~ /0000/
          alt_ids << id

          if id =~ /tlg|phi|stoa|lccn/i #might need to expand this for LCCN, VIAF, etc. if we start using them
            if found_id =~ /tlg|phi|stoa/
              #skip, having a hell of a time making it work with 'unless'
            else
              found_id = id 
            end
          end         
        end
      end
      #if no id found throw an error   
      unless found_id    
        message = "For file #{f_n} : Could not find a suitable id, please check 
        that there is a tlg, phi, or stoa id or that, if a mads, the mads namespace is present."
        error_handler(message, file_path, f_n)
        return
      else
        alt_ids.delete(found_id)
        return found_id, alt_ids.join(';')
      end
    rescue 
      message = "For file #{f_n} : There was an error while trying to find an id, error message was #{$!}."
      error_handler(message, file_path, f_n)
      return
    end
  end

  def create_label_desc(mods_xml)
    ns = mods_xml.collect_namespaces
    if !mods_xml.search('//mods:relatedItem[@type="host"]/mods:titleInfo', ns).empty?
      raw_title = mods_xml.search('//mods:relatedItem[@type="host"]/mods:titleInfo', ns).first
    elsif !mods_xml.search('//mods:titleInfo', ns).empty?
      raw_title = mods_xml.search('//mods:titleInfo', ns).first
    elsif !mods_xml.search('//mods:titleInfo[@type="alternative"]', ns).empty?
      raw_title = mods_xml.search('//mods:titleInfo[@type="alternative"]', ns).first
    elsif !mods_xml.search('//mods:titleInfo[@type="translated"]', ns).empty?
      raw_title = mods_xml.search('//mods:titleInfo[@type="translated"]', ns).first
    else
      raw_title = mods_xml.search('//mods:titleInfo[@type="uniform"]', ns)                  
    end                
    
    label = xml_clean(raw_title, ' ')

    names = mods_xml.search('//mods:name', ns)
    ed_trans = ""
    author_n = ""
    names.each do |m_name|
      if m_name.inner_text =~ /editor|translator|compiler/
        ed_trans = xml_clean(m_name, ",")
      elsif m_name.inner_text =~ /creator|attributed author/
        author_n = xml_clean(m_name, ",")
        author_n.gsub!(/,,/, ",")
      end
    end
    
    description = "#{author_n}; #{ed_trans}"
    
    return label, description
  end

  def add_mods_prefix(mods_xml)    
    mods_xml.root.add_namespace_definition("mods", "http://www.loc.gov/mods/v3")
    mods_xml.root.name = "mods:#{mods_xml.root.name}"
    mods_xml.root.children.each {|chil| xml_rename(chil)}    
  end

  def xml_rename(node)
    m_name = node.name
    node.name = "mods:#{m_name}"
    m_chil = node.children    
    m_chil.each {|c_node| xml_rename(c_node)} if m_chil
  end

  def get_xml(file)
    file_string = File.open(file, "r+")
    file_xml = Nokogiri::XML::Document.parse(file_string, &:noblanks)
    file_string.close
    return file_xml
  end

#cleaning data

  def clean_dirs(dir)
    dirs_arr = Dir.entries(dir).map {|e| File.join(dir, e)}.select{|f| f unless f =~ /\.$/ || f =~ /\.\.$/ || f =~ /DS_Store/ || f =~ /README/}
  end

  def clean_id(node)
    if node.attribute('type')
      val = node.attribute('type').value
      if val
        id = node.inner_text
        unless id == "none" || id == "" 
          #stoas only need the - removed
          if id =~/(stoa\d+[a-z]*-|stoa\d+[a-z]*)/
            id = id.gsub('-', '.')      
          else
            if val =~ /tlg|phi/
              if id =~ /\d+x\d$/i #catching 0012X01 type of ids
                id_step = id.split(/x/i)
                id_step[1]= "X"+id_step[1]
                #add in tlgs or phis
                id = id_step.map {|x| val + x}.join(".")
              else
                #I hate that the ids aren't padded with 0s...           
                id_step = id.split(".")
                id_step.each_with_index {|x, i| i == 0 ? id_step[0] = sprintf("%04d", x.to_i) : id_step[1] = sprintf("%03d", x.to_i)}
                #add in tlgs or phis
                id = id_step.map {|x| val + x.to_s}.join(".") 
              end             
            else              
              id = "VIAF" + id[/\d+$/] if id =~ /viaf/
              id = "LCCN " + id[/(n|nr)\s+\d+/] if id =~ /(n|nr)\s+\d+/
              #have abo ids to account for
              if id =~ /Perseus:abo/ && id !~ /ltan/
                id_parts = id.split(",")
                id_type = id_parts[0].split(":")[2]
                id = id_type + id_parts[1] + "." + id_type + id_parts[2]
              end
            end
          end
        end
        return id
      end
    end
  end

  def xml_clean(nodes, sep = "")
    empty_test = nodes.class == "Nokogiri::XML::NodeSet" ? nodes.empty? : nodes.blank?
    unless empty_test
      cleaner = ""
      nodes.children.each do |x| 
        cleaner << x.inner_text + sep
      end
      clean = cleaner.gsub(/\s+#{sep}|\s{2, 5}|#{sep}$/, " ").strip
      return clean
    else
      return ""
    end
  end

#errors
  def error_handler(message, *file_info)
    puts message
    @error_report << "#{message}\n\n"
    @error_report.close
    @error_report = File.open("#{ENV['HOME']}/catalog_pending/errors/error_log#{Date.today}.txt", 'a')
    #`mv "#{file_path}" "#{ENV['HOME']}/catalog_pending/errors#{f_n}"`
  end

#for testing new paths
  def test_run(message, values)
    test_file = File.open("#{ENV['HOME']}/catalog_pending/test_run#{Date.today}.txt", 'a')
    test_file << "#{message}\n#{values}\n\n"
    test_file.close
  end

end
