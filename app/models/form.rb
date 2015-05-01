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

  def self.build_vers_info(params)
    #v_type, lang_code, perseus_check, w_cts, w_title, w_lang
    vers_info = [["urn", "version", "label_eng", "desc_eng", "type", "has_mods", "urn_status", "redirect_to", "member_of", "created_by", "edited_by"]]
    vers_cite = Version.generate_urn
    vers_urn = Form.cts_urn_build(params[:w_cts], params[:perseus_check], params[:lang_code])
    vers_info << ["#{vers_cite}", "#{vers_urn}", "#{params[:w_title]}", "", "#{params[:v_type]}", 'false', 'reserved','','','form_maker', '']
  end


  def self.cts_urn_build(w_cts, mem_of, lang)
    v_cts_no_num = "#{w_cts}.#{mem_of}-#{lang}"
    existing_vers = Version.find_by_cts(v_cts_no_num)
    if existing_vers.length == 0
      vers_urn = "#{v_cts_no_num}1"
    else
      num = nil
      existing_vers.each do |line|
        curr_urn = line[:version][/#{v_cts_no_num}\d+/]
        urn_num = curr_urn[/\d+$/].to_i
        num = urn_num + 1
      end
      vers_urn = "#{v_cts_no_num}#{num}"
    end
    return vers_urn   
  end

  def self.build_row(vers_arr)
    row = Version.add_cite_row(vers_arr)
  end 

end