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
    path_name = "#{BASE_DIR}/catalog_data/mods/"
    ctsmain = ctsurn[/(greekLit|latinLit|arabicLit).+/]
    path_name << "#{ctsmain.gsub(/:|\./, "/")}"
    unless File.exists?(path_name)
      FileUtils.mkdir_p(path_name)
    end
    if File.exists?(path_name)
      Dir.chdir(path_name)
      sansgl = ctsmain.gsub(/greekLit:|latinLit:|arabicLit:/, "")
      mods = Dir["#{sansgl}.*"]
      mods_num = 0
      mods.each {|x| mods_num = mods_num < x[/\d+\.xml/].chr.to_i ? x[/\d+\.xml/].chr.to_i : mods_num}
      modspath = "#{path_name}/#{sansgl}.mods#{mods_num + 1}.xml"
    end
    return modspath
  end  

  def create_mads_path(old_path)
    path_name = "#{BASE_DIR}/catalog_data/mads/PrimaryAuthors/"
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

#find files changed within the last week
  def get_recent_changes(path)  
    today = Time.now
    week_earlier = today - (60 * 60 * 24 * 7)
    changes = []
    Dir.glob("#{path}/**/*.xml") {|f| changes << f if (File.mtime(f) <=> week_earlier) == 1}
    return changes
  end

#find things in the XML

  def find_basic_info(xml_record, file_path, ctsurn=nil)
    begin
      #get a file name that I had earlier but cleverly turned into the path that I needed then...
      f_n = file_path[/(\/[\w\s\.\(\)-]+)?\.xml/]
      id, alt_ids = find_rec_id(xml_record, file_path, f_n)
      #if a work level cts urn is provided in the record, default to that
      if ctsurn
        id = ctsurn
      end
      #this and the find_rec_id will need to be updated to accommodate different ids
      unless f_n =~ /mads/
        lit_type, lit_abbr = get_lang_info(id)
        if lit_type.empty? && lit_abbr.empty?
          message = "Unrecognized id type, #{id}"
          error_handler(message, true)
        end
        w_id = id =~ /cts/ ? id[/urn:cts:\w+:\w+\.\w+/] : "urn:cts:#{lit_type}Lit:#{id}"
        tg_id = w_id[/urn:cts:\w+:\w+/]
        canon_id = tg_id[/\w+$/]
      else
        w_id = nil
        tg_id = nil
        canon_id = id[/\w+$/]
      end
      if id
        #search for and compare author values
        auth_name = find_rec_author(xml_record, file_path, f_n)
        auth_nset = Author.get_by_id(canon_id) 
        auth_nset = Author.get_by_name(auth_name) if auth_nset.empty?     
        tg_nset = Textgroup.find_by_id(tg_id)   
        
        info_hash = { :file_name => f_n,
                      :path => file_path,
                      :canon_id => canon_id,
                      :a_name => auth_name,
                      :tg_id => tg_id,
                      :alt_ids => alt_ids,
                      :cite_auth => auth_nset,
                      :cite_tg => tg_nset}

        if f_n =~ /mods/
          work_title = nil
          title_ns = xml_record.search("/mods:mods/mods:titleInfo")
          title_ns = xml_record.search("./mods:titleInfo") if title_ns.empty?
          title_ns.each do |title_node|
            #take uniform if it exists
            type = title_node.attribute("type")
            if type && type.value == "uniform"
              work_title = title_node.search("./mods:title").inner_text
              break
            elsif work_title == nil && type == nil
              work_title = title_node.search("./mods:title").inner_text
            end
            unless work_title
              work_title = title_node.search("./mods:title").inner_text
            end
          end
  
          work_row = Work.find_by_id(w_id)   
          orig_lang = lit_abbr
          vers_langs = []
          #take language nodes from the edition not the host (need to be careful of constituent records?)
          ed_lang_nodes = xml_record.search("/mods:mods/mods:language")
          ed_lang_nodes = xml_record.search("./mods:language") if ed_lang_nodes.empty?
          #if no languages throw error
          if ed_lang_nodes.empty?
            message = "No language found for the edition, please review!"
            error_handler(message, true)
          end
          ed_lang_nodes.each do |x|
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
          related_works = collect_rel_works(xml_record)
          info_hash.merge!(:related_works => related_works.join(';'))
        end
        
        return info_hash       
      end
    rescue Exception => e
      message = "For file #{file_path}: something went wrong, #{$!} #{e.backtrace}"
      error_handler(message, false)
      return nil
    end
  end

  def collect_rel_works(xml_record)
    extensions = xml_record.search("/mads:mads/mads:extension")
    related_works = []
    extensions.children.each do |node|           
      unless node.inner_text =~ /related work identifiers/
        related_works << clean_id(node) if node.name == "identifier"
      end
    end
    return related_works
  end

  def get_lang_info(id)
    ids_file = File.read("#{BASE_DIR}/cite_collections_rails/data/id_to_lang.csv").split("\n")
    lang = ""
    lang_abbr = ""
    ids_file.each do |line|
      line_arr = line.split(',')
      if id =~ /#{line_arr[0]}/
        lang = line_arr[1] 
        lang_abbr = line_arr[2]
      elsif id =~ /#{line_arr[1]}/ || id =~ /#{line_arr[2]}/
        #for if a cts urn gets passed in, or one like Maxim's ids
        lang = line_arr[1] 
        lang_abbr = line_arr[2]
      end
    end
    return lang, lang_abbr
  end


  def find_rec_author(xml_record, file_path, f_n)
    begin
      ns = xml_record.document.collect_namespaces
      #grab mads authority name
      if f_n =~ /mads/ 
        #handles both regular mads files and those for a work, e.g. Scriptores Historiae Augusta
        authority_names = xml_record.search(".//mads:mads/mads:authority", ns)
        if authority_names.empty?
          #so far this is only the Appendix Vergiliana
          name_ns = xml_record.search(".//mads:mads/mads:variant", ns)[0]
        else
          name_ns = authority_names.search(".//mads:name/mads:namePart", ns)
          name_ns = authority_names.search(".//mads:titleInfo/mads:title", ns) if name_ns.empty?
        end
        n = [] 
        unless name_ns.empty?
          name_ns.each {|x| n << x.inner_text}
          a_name = n.join(" ")
        else
          message = "For file #{f_n} : Could not find an authority name, please check the record."
          error_handler(message, false)
          return
        end
      else        
        names = {}     
        name_ns = xml_record.search("/mods:mods/mods:name", ns)
        name_ns = xml_record.search("./mods:name", ns) if name_ns.empty?
        unless name_ns.empty?
          name_ns.each do |node|
            a_type = node.search("./mods:role/mods:roleTerm", ns).inner_text
            if a_type =~ /creator$|author|attributed/
              n = []
              node.search("./mods:namePart", ns).each {|x| n << x.inner_text}
              names[a_type] = n.join(" ")             
            end
          end
          if names.empty?
            #if there is no name, need to take the title instead, for anonymous works
            raw_title = xml_record.search('//mods:titleInfo[@type="uniform"]', ns).first
            raw_title = xml_record.search('//mods:titleInfo[not(@type)]', ns).first if raw_title == nil
            unless raw_title == nil
              a_name = xml_clean(raw_title, " ")
            else
              message = "For file #{f_n} : Could not find an author name, please check the record."
              error_handler(message, false)
              return
            end
          else
            if names.size == 1
              a_name = names.values[0] 
            else
              a_name = names["creator"] ? names["creator"] : names.values[0]
            end 
          end
        else
          #if there is no name, need to take the title instead, for anonymous works
          raw_title = xml_record.search('//mods:titleInfo[@type="uniform"]', ns).first
          raw_title = xml_record.search('//mods:titleInfo[not(@type)]', ns).first if raw_title. == nil
          unless raw_title.empty?
            a_name = xml_clean(raw_title, " ")
          else
            message = "For file #{f_n} : Could not find an author name, please check the record."
            error_handler(message, false)
            return
          end
        end
      end
      return a_name
    rescue
      message = "For file #{f_n} : There was an error while trying to find the author, error message was #{$!}."
      error_handler(message, true)
    end
  end


  def find_rec_id(xml_record, file_path, f_n)

    begin
      ids = f_n =~ /mads/ ? xml_record.search("/mads:mads/mads:identifier") : xml_record.search("/mods:mods/mods:identifier")
      ids = xml_record.search("./mods:identifier") if ids.empty?
      found_id = nil
      alt_ids = []
      main_type = ""
      related_works = collect_rel_works(xml_record) if f_n =~ /mads/

      #parsing found ids, take tlg or phi over stoa unless there is an empty string or "none"
      ids.each do |node|
        #this is a stopgap until we have a procedure for assigning ids to commentaries
        if node.attribute('displayLabel')
          val = node.attribute('displayLabel').value
          if val == 'isCommentaryOn'
            message = "#{f_n} is a commentary, saving for another time"
            error_handler(message, false)
            return
          elsif val == "Pseudo"
            #Pseudo author in main author MADS, need to add a separate cite row
            id = clean_id(node)
            add_pseudo_auth(id, xml_record, file_path, f_n)
            next
          end
        end
        id = clean_id(node)
        type = node.attribute("type") ? node.attribute("type").value : nil
      
        unless id =~ /none/i || id == "" || id =~ /0000|\D000$/ || id =~ /\?/ || id =~ /urn:cts|urn:cite/
          alt_ids << id  
                 
          unless f_n =~ /mads/
            test_arr = id.split(".")
            if test_arr.length == 2
              if found_id =~ /stoa/ && id =~ /phi/
                found_id = id
              else
                found_id = id 
              end
            end
          else
            #compare id to rel_works if they exist, if matches most common, found_id = id
            unless related_works.empty?
              res = related_works.select{|cont| cont =~ /#{id}/}
              if ((related_works.length - res.length) <= (related_works.length / 2))
                found_id = id
              end
            else
              #if no rel_works take whatever with priority to the regular ones
              #if it has a lccn or viaf id in found try to replace it
              if found_id =~ /lccn|viaf/i
                unless id =~ /lccn|viaf/i
                  found_id = id
                end
              #if the new id is lccn or viaf and the found is not don't replace
              else
                unless id =~ /lccn|viaf/i
                  if found_id =~ /stoa/ && id =~ /phi/
                    found_id = id
                  else
                    found_id = id 
                  end
                else
                  found_id = id if found_id == nil
                end           
              end
            end
          end         
        end
      end

      #if no id found throw an error   
      unless found_id    
        message = "For file #{f_n} : Could not find a suitable id, please check 
        that there is a standard id, that there are no ?'s, or that, if a mads, the mads namespace is present."
        error_handler(message, true)
        return
      else
        alt_ids.delete(found_id)
        return found_id, alt_ids.join(';')
      end
    rescue 
      message = "For file #{f_n} : There was an error while trying to find an id, error message was #{$!}."
      error_handler(message, true)
      return
    end
  end

  def create_label_desc(mods_xml)
    ns = mods_xml.document.collect_namespaces
    if !mods_xml.search('//mods:relatedItem[@type="host"]/mods:titleInfo', ns).empty?
      raw_title = mods_xml.search('//mods:relatedItem[@type="host"]/mods:titleInfo', ns).first
    elsif !mods_xml.search('//mods:titleInfo[not(@type)]', ns).empty?
      raw_title = mods_xml.search('//mods:titleInfo[not(@type)]', ns).first
    elsif !mods_xml.search('//mods:titleInfo[@type="alternative"]', ns).empty?
      raw_title = mods_xml.search('//mods:titleInfo[@type="alternative"]', ns).first
    elsif !mods_xml.search('//mods:titleInfo[@type="translated"]', ns).empty?
      raw_title = mods_xml.search('//mods:titleInfo[@type="translated"]', ns).first
    else
      raw_title = mods_xml.search('//mods:titleInfo[@type="uniform"]', ns)                  
    end                
    
    label = xml_clean(raw_title, ' ')

    names = mods_xml.search('//mods:name', ns)
    ed_trans_arr = []
    author_arr = []
    names.each do |m_name|
      if m_name.inner_text =~ /editor|translator|compiler/
        ed_trans = xml_clean(m_name, ", ")
        ed_trans.gsub!(/,,|\.,/, ",")
        ed_trans_arr << ed_trans
      elsif m_name.inner_text =~ /creator|attributed author/
        author_n = xml_clean(m_name, ", ")
        author_n.gsub!(/,,|\.,/, ",")
        author_arr << author_n
      end
    end
    ed_trans_arr.uniq!
    author_arr.uniq!
    description = "#{author_arr.join('; ')}; #{ed_trans_arr.join('; ')}"
    
    return label, description
  end

  def add_pseudo_auth(id, xml_record, file_path, f_n)
    auth_arr = []
    auth_arr << Author.generate_urn
    auth_arr << find_rec_author(xml_record, file_path, f_n)
    auth_arr << id
    auth_arr << file_path[/PrimaryAuthors.+/]
    alt_ids = xml_record.search("/mads:mads/mads:identifier[not(@type='Pseudo')]")
    auth_arr << alt_ids.join(";")
    rel_works = xml_record.search("/mads:mads/mads:extension/mads:identifier")
    w_match = rel_works.collect {|rw| rw =~ id} if rel_works
    auth_arr << w_match.join(";")
    auth_arr << ["published", "", "auto_import", ""]
    Author.add_cite_row(auth_arr)    
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
    dirs_arr = Dir.glob("#{dir}/**/*.xml")
  end

  #!! need to update this method for newly coined urns, expand the scope
  def clean_id(node)
    if node.attribute('type')
      val = node.attribute('type').value
      if val
        id = node.inner_text.strip
        unless id == "none" || id == "" || id =~ /\?/
          #stoas only need the - removed
          if id =~/(stoa\d+[a-z]*-|stoa\d+[a-z]*)/
            id = id.gsub('-', '.')      
          else
            if val =~ /tlg|phi/
              if id =~ /^\d+x\d+$/i #catching 0012X01 type of ids
                id_step = id.split(/x/i)
                id_step[1]= "X"+id_step[1]
                #add in tlgs or phis
                id = id_step.map {|x| val + x}.join(".")
              else
                #I hate that the ids aren't always padded with 0s...           
                id_step = id.split(".")
                id_step.each_with_index do |x, i| 
                  if i == 0
                    id_step[0] = sprintf("%04d", x.to_i) if id_step[0].length < 4 
                  else
                    id_step[1] = sprintf("%03d", x.to_i) if id_step[1].length < 3
                  end
                end
                #add in tlgs or phis
                id = id_step.map {|x| val + x.to_s}.join(".") 
              end             
            else              
              id = "VIAF" + id[/\d+$/] if id =~ /viaf/
              id = "LCCN " + id[/(n|nr|nb|no)\s+\d+/] if id =~ /(n|nr)\s+\d+/
              #have abo ids to account for
              if id =~ /Perseus:abo/ && id !~ /ltan|bede/
                id_parts = id.split(",")
                id_type = id_parts[0].split(":")[2]
                if id_parts.length < 3
                  id = id_type + id_parts[1]
                else
                  id = id_type + id_parts[1] + "." + id_type + id_parts[2]
                end
              end
            end
          end
        end
        return id
      end
    elsif node.inner_text =~ /Perseus:text/i
      id = node.inner_text.strip
      return id
    end
  end

  def xml_clean(nodes, sep = "")
    empty_test = nodes.class == "Nokogiri::XML::NodeSet" ? nodes.empty? : nodes.blank?
    unless empty_test
      cleaner = ""
      even_cleaner = ""
      nodes.children.each do |x|
        cleaner << (x.name == "nonSort" ? "#{x.inner_text} " : x.inner_text + sep)
        #this step removes any XML escaped characters, don't know why parse doesn't do it
        even_cleaner = Nokogiri::XML.fragment(cleaner).inner_text
      end
      clean = even_cleaner.gsub(/\s+#{sep}|\s{2, 5}|#{sep}$/, " ").strip
      return clean
    else
      return ""
    end
  end

#errors
  def error_handler(message, to_raise)
    puts message
    @error_report << "#{message}\n\n"
    @error_report.close
    @error_report = File.open("#{BASE_DIR}/catalog_pending/errors/error_log#{Date.today}.txt", 'a')   
    raise if to_raise
    #`mv "#{file_path}" "#{BASE_DIR}/catalog_pending/errors/#{f_n}"`
  end

  def delete_dirs(pending)
    Dir["#{pending}/**/"].reverse_each do |d|
      File.delete("#{d}.DS_Store") if File.exists?("#{d}.DS_Store")
      Dir.rmdir d if Dir.entries(d).size == 2 
    end
  end

end
