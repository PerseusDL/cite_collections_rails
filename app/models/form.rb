class Form
  include ActiveModel::Model
  require 'mods_record_builder.rb'

  attr_accessor :field_type

  def self.search(params)
    wrks = nil
    if params[:title_eng]
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
    unless params[:v_cts]
      vers_urn = Form.cts_urn_build(p[:w_cts], p[:perseus_check], p[:lang_code])
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{p[:w_title]}", "", "#{p[:v_type]}", 'false', 'reserved','','',"#{p[:name]}", '']
    else
      vers_no_num = params[:v_cts][/[\w|:|\.]+-[a-z]+/]
      existing_vers = Version.find_by_cts(vers_no_num)
      num = Version.cts_num_incr(existing_vers, vers_no_num)
      vers_urn = "#{vers_no_num}#{num}"
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{p[:v_label]}", "#{p[:v_desc]}", "#{p[:v_type]}", 'false', 'reserved','','',"#{p[:name]}", '']
    end
    return vers_info
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


  def self.build_row(vers_arr)
    #row = Version.add_cite_row(vers_arr)
    row = "Wheee"
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
    w_cts = namespace != "" ? "urn:cts:#{p[:namespace]}:#{p[:p_id]}" : "urn:cts:#{p[:o_namespace]}:#{p[:p_id]}"
    #need to continue building this, then can get rid of urn build below it
    vb_arr = {:w_cts => w_cts, :lang_code => p[:lang]}
    v_cts_urn = Form.cts_urn_build(w_cts, p[:perseus_check], p[:lang])
    v_cite = Version.generate_urn
    id_node = mods_xml.search("/mods:mods/mods:identifier").last
    n_id = Nokogiri::XML::Node.new "mods:identifier", mods_xml
    n_id.add_namespace_definition("mods", "http://www.loc.gov/mods/v3")
    n_id.content = v_cts_urn
    n_id.set_attribute("type", "ctsurn")
    id_node.add_next_sibling(n_id)

    #need hash of v_type, lang_code, perseus_check, name, w_cts, w_title, w_lang
    #arr = Forms.build_vers_info()
    return mods_xml
  end

end