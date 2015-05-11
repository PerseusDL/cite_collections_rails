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

  def self.build_vers_info(params)
    #v_type, lang_code, perseus_check, name, w_cts, w_title, w_lang
    vers_info = [["urn", "version", "label_eng", "desc_eng", "type", "has_mods", "urn_status", "redirect_to", "member_of", "created_by", "edited_by"]]
    vers_cite = Version.generate_urn
    unless params[:v_cts]
      vers_urn = Form.cts_urn_build(params[:w_cts], params[:perseus_check], params[:lang_code])
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{params[:w_title]}", "", "#{params[:v_type]}", 'false', 'reserved','','',"#{params[:name]}", '']
    else
      vers_no_num = params[:v_cts][/[\w|:|\.]+-[a-z]+/]
      existing_vers = Version.find_by_cts(vers_no_num)
      num = Version.cts_num_incr(existing_vers, vers_no_num)
      vers_urn = "#{vers_no_num}#{num}"
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{params[:v_label]}", "#{params[:v_desc]}", "#{params[:v_type]}", 'false', 'reserved','','',"#{params[:name]}", '']
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
    byebug
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
  end

end