class Form
  include ActiveModel::Model

  attr_accessor :field_type

  def self.search(params)
    if params['field_type'] == "work"
      #search works
      res = Work.lookup(params)
    else
      #search versions
      res = Version.lookup(params)
    end
    return res
  end

  def self.build_vers_info(params, ex_row = nil)
    #v_type, lang_code, perseus_check, name, w_cts, w_title, w_lang
    vers_info = [["urn", "version", "label_eng", "desc_eng", "type", "has_mods", "urn_status", "redirect_to", "member_of", "created_by", "edited_by"]]
    vers_cite = Version.generate_urn
    unless ex_row
      vers_urn = Form.cts_urn_build(params[:w_cts], params[:perseus_check], params[:lang_code])
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{params[:w_title]}", "", "#{params[:v_type]}", 'false', 'reserved','','',"#{params[:name]}", '']
    else
      vers_no_num = ex_row.version[/[\w|:|\.]+-[a-z]+/]
      existing_vers = Version.find_by_cts(vers_no_num)
      num = Version.cts_num_incr(existing_vers, vers_no_num)
      vers_urn = "#{vers_no_num}#{num}"
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{ex_row.label_eng}", "#{ex_row.desc_eng}", "#{ex_row.ver_type}", 'false', 'reserved','','',"#{params[:name]}", '']
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

end