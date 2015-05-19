class Form
  include ActiveModel::Model
  require 'mods_record_builder.rb'

  attr_accessor :field_type

  def self.search(params)
    wrks = nil
    if params[:title_eng] && params[:title_eng] != ""
      wrks = Work.where("title_eng rlike ?", params[:title_eng]).to_a
      res = wrks
    end
    if params[:authority_name]
      res = Author.where("authority_name rlike ?", params[:authority_name])
      combo = []
      
      res.each do |a|
        combo_start =[]
        combo_start << a
        if wrks
          wrks.each do |w|
            if w.work =~ /#{a.canonical_id}/
              combo_start << w
            end
          end
        else
          w_arr = a.related_works.split(';')
          w_arr.each do |w_id|
            rel_works = Work.where("work rlike ?", w_id)
            rel_works.each {|w| combo_start << w} if rel_works
          end
        end
        if combo_start.length > 1
          combo_start.map {|c| combo << c}
        end
      end  
      res = combo
      res = "" if res == []
    elsif params[:field_type] == "work"
        #search works
        res = Work.lookup(params)
    elsif params[:field_type] == "version"
      #search versions
      res = Version.lookup(params)
    end
    return res
  end

  def self.build_vers_info(p)
    #v_type, lang_code, perseus_check, name, w_cts, w_title, w_lang
    vers_info = [["urn", "version", "label_eng", "desc_eng", "type", "has_mods", "urn_status", "redirect_to", "member_of", "created_by", "edited_by"]]
    vers_cite = Version.generate_urn
    unless p[:v_cts]
      vers_urn = Form.cts_urn_build(p[:w_cts], p[:perseus_check], p[:lang_code])
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{p[:w_title]}", "", "#{p[:v_type]}", 'false', 'reserved','','',"#{p[:name]}", '']
    else
      vers_no_num = p[:v_cts][/[\w|:|\.]+-[a-z]+/]
      existing_vers = Version.find_by_cts(vers_no_num)
      num = Version.cts_num_incr(existing_vers, vers_no_num)
      vers_urn = "#{vers_no_num}#{num}"
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{p[:v_label]}", "#{p[:v_desc]}", "#{p[:v_type]}", 'false', 'reserved','','',"#{p[:name]}", '']
    end
    return vers_info
  end

  def self.build_work_info(p)
    work_info = [["urn", "work", "title_eng", "orig_lang", "notes", "urn_status", "redirect_to", "created_by", "edited_by"]]
    work_cite = Work.generate_urn
  end

  def self.build_tg_info(p)
    tg_info = [["urn", "textgroup", "groupname_eng", "has_mads", "mads_possible", "notes", "urn_status", "redirect_to", "created_by", "edited_by"]]
    tg_cite = Textgroup.generate_urn
  end


  def self.cts_urn_build(w_cts, mem_of, lang)
    v_cts_no_num = "#{w_cts}.#{mem_of}-#{lang}"
    existing_vers = Version.find_by_cts(v_cts_no_num)
    if existing_vers.length == 0
      vers_urn = "#{v_cts_no_num}1"
    else
      num = Version.cts_num_incr(existing_vers, v_cts_no_num)
      vers_urn = "#{v_cts_no_num}#{num}"
    end
    return vers_urn   
  end

  def self.build_work_info(work_arr)
    #row = Work.add_cite_row(work_arr)
  end

  def self.build_tg_info(tg_arr)
    #row = Textgroup.add_cite_row(tg_arr)
  end

  def self.build_row(vers_arr)
    #row = Version.add_cite_row(vers_arr)
    row = "Wheee"
  end 

  def self.save_mods(mods, array)
    path = "#{BASE_DIR}/catalog_pending/for_approval/#{array[1]}.xml"
    xml = File.new(path, "w")
    xml << mods
    xml.save
    xml.close
    return path
  end


  def self.mods_creation(p)
    info_arr = [p[:p_id], 
                p[:p_id_type], 
                p[:alt_id] == "" ? "" : p[:alt_id] + "|" + p[:alt_id_type] , 
                p[:title], 
                "", 
                p[:a_name],
                p[:t_o_a],
                p[:a_dates],
                "",
                p[:e_name] == "" ? "" : "editor",
                p[:e_name],
                "", "", "",
                p[:t_name] == "" ? "" : "translator",
                p[:t_name],
                "", "", "",
                "", "", "", "", "",
                p[:manuscript],
                p[:p_country],
                p[:p_city],
                p[:publisher],
                p[:manuscript] == "false" ? p[:date] : "",
                p[:manuscript] == "true" ? p[:date] : "",
                "",
                p[:edition],
                p[:lang],
                "", 
                p[:phys_desc],
                 "", "", "", "",
                p[:series],
                p[:url] == "" ? "" : p[:url_label] + "|" + p[:url]
              ]
    build = ModsRecordBuilder.new
    mods_xml = build.mods_builder(info_arr)

    #perseus_check, namespace, o_namespace
    #build work cts
    unless p[:w_cts] == ""
      w_cts = p[:w_cts]
    else
      w_cts = namespace != "" ? "urn:cts:#{p[:namespace]}:#{p[:p_id]}" : "urn:cts:#{p[:o_namespace]}:#{p[:p_id]}"
    end
    #need hash of v_type, lang_code, perseus_check, name, w_cts, w_title, w_lang
    v_type = p[:w_lang] == p[:lang] ? "edition" : "translation"
    vb_arr = {:v_type => v_type, :lang_code => p[:lang], :perseus_check => p[:perseus_check], 
      :name => p[:name], :w_cts => w_cts, :w_title => p[:title], :w_lang => p[:w_lang]}
    arr = Form.build_vers_info(vb_arr)
    #mods_xml is string, needs to be xml again
    mods_xml = Nokogiri::XML::Document.parse(mods_xml, &:noblanks)
    id_node = mods_xml.search("/mods:mods/mods:identifier").last
    n_id = Nokogiri::XML::Node.new "mods:identifier", mods_xml
    n_id.add_namespace_definition("mods", "http://www.loc.gov/mods/v3")
    n_id.content = arr[1][1]
    n_id.set_attribute("type", "ctsurn")
    id_node.add_next_sibling(n_id)

    return mods_xml.to_xml, arr
  end
  

  def self.mads_creation(p)
    #0authority name, 1authority term of address, 2authority dates, 3alt names(parts sep by ;, multi names sep by |),
    #4main identifier, 5id type, 6alt ids, 7source note, 8field of activity, 
    #9urls, 10related works
    alt_names = p[:a_alt_name] + ";" + p[:alt_lang] + ";" + p[:alt_t_o_a] + ";" + p[:alt_a_dates]
    alt_ids = p[:alt_id] + ";" + p[:alt_id_type]
    related_works = p[:rel_w] + ";" + p[:rel_id_type]
    
    info_arr = [p[:a_name],
                p[:t_o_a],
                p[:a_dates],
                alt_names,
                p[:p_id],
                p[:p_id_type],
                alt_ids,
                p[:notes],
                p[:f_o_a],
                p[:url],
                p[:url_label],
                related_works
              ]
    build = MadsRecordBuilder.new
    mads_xml = build.mads_builder(info_arr)
    #need to add cite urn
  end

end