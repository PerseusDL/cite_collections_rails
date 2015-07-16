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
      if p[:a_name]
        desc_start = p[:a_name]
      else
        row = Textgroup.find_by_id(p[:w_cts][/urn:cts:\w+:\w+/])
        desc_start = row ? row[2] : ""
      end
      desc_start << ";" + p[:e_name] if p[:e_name]
      desc_start << ";" + p[:t_name] if p[:t_name]
      vers_info << ["#{vers_cite}", "#{vers_urn}", "#{p[:w_title]}", "#{desc_start}", "#{p[:v_type]}", 'false', 'reserved','','',"#{p[:name]}", '']
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
    work_info << ["#{work_cite}", "#{p[:w_cts]}", "#{p[:title]}", "#{p[:lang]}", "", "reserved", "", "#{p[:name]}", ""]
  end

  def self.build_tg_info(p)
    tg_info = [["urn", "textgroup", "groupname_eng", "has_mads", "mads_possible", "notes", "urn_status", "redirect_to", "created_by", "edited_by"]]
    tg_cite = Textgroup.generate_urn
    tg_info << ["#{tg_cite}", "#{p[:cts]}", "#{p[:tg_name]}", "false", "true", "", "reserved", "", "#{p[:name]}", ""]
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

  def self.build_work_row(work_arr)
    row = Work.add_cite_row(work_arr)
  end

  def self.build_tg_row(tg_arr)
    row = Textgroup.add_cite_row(tg_arr)
  end

  def self.build_row(vers_arr)
    row = Version.add_cite_row(vers_arr)
    return vers_arr
  end 

  def self.build_auth_row(auth_arr)
    row = Author.add_cite_row(auth_arr)
    return auth_arr
  end 

  def self.save_xml(mods, array)
    path = "#{BASE_DIR}/catalog_pending/for_approval/#{array[1]}.xml"
    xml = File.new(path, "w")
    xml << mods
    xml.save
    xml.close
    return path[/catalog_pending.+/]
  end


  def self.mods_creation(p)
    info_arr = [p[:p_id],
                p[:p_id_type],
                p[:alt_ids],
                p[:title],
                p[:alt_titles],
                p[:a_name],
                p[:a_t_o_a],
                p[:a_date],
                "#{p[:a_auth]};#{p[:a_authURI]};#{p[:a_valueURI]}",
                p[:ed_or_t1],
                p[:ed_or_t1_name],
                p[:ed_or_t1_t_o_a],
                p[:ed_or_t1_date],
                "#{p[:ed_or_t1_auth]};#{p[:ed_or_t1_authURI]};#{p[:ed_or_t1_valueURI]}",
                p[:ed_or_t2],
                p[:ed_or_t2_name],
                p[:ed_or_t2_t_o_a],
                p[:ed_or_t2_date],
                "#{p[:ed_or_t2_auth]};#{p[:ed_or_t2_authURI]};#{p[:ed_or_t2_valueURI]}",
                p[:ed_or_t3],
                p[:ed_or_t3_name],
                p[:ed_or_t3_t_o_a],
                p[:ed_or_t3_date],
                "#{p[:ed_or_t3_auth]};#{p[:ed_or_t3_authURI]};#{p[:ed_or_t3_valueURI]}",
                p[:ms?],
                p[:c_code],
                p[:city],
                p[:pub],
                p[:date_i],
                p[:date_c],
                p[:date_m],
                p[:edition],
                p[:lang_code],
                p[:other_langs],
                p[:extent_desc],
                p[:pg_s],
                p[:pg_e],
                p[:pg_range],
                p[:topics],
                p[:series_title],
                p[:online_loc],
                p[:phys_loc],
                p[:shelf_loc],
                p[:notes],
                p[:t_of_c],
                p[:multi?]
              ]
    build = ModsRecordBuilder.new

    mods_xml = build.mods_builder(info_arr)

    #perseus_check, namespace, o_namespace
    #build work cts
    if p[:w_cts] 
      w_cts = p[:w_cts]
    else
      w_cts = p[:namespace] != "" ? "urn:cts:#{p[:namespace]}:#{p[:p_id]}" : "urn:cts:#{p[:o_namespace]}:#{p[:p_id]}"
    end

    #need hash of v_type, lang_code, perseus_check, name, w_cts, w_title, w_lang
    v_type = p[:w_lang] == p[:lang_code] ? "edition" : "translation"
    vb_arr = {:v_type => v_type, :lang_code => p[:lang_code], :perseus_check => p[:perseus_check], 
      :name => p[:name], :w_cts => w_cts, :w_title => p[:title], :w_lang => p[:w_lang]}
    arr = Form.build_vers_info(vb_arr)


    #if multivolume:
    #look for existing reserved version, but how do we know which version to look for?
    #if there, pull existing pending mods 
      #(if it exists else create it), add appropriate id, tack mods to end, add ctsurn?
      #mods_xml gets the entire collection file
      #don't update the version, just return that row?
    #else, put in modsCollection and give id, then proceed as usual

    #mods_xml is string, needs to be xml again
    mods_xml = Nokogiri::XML::Document.parse(mods_xml, &:noblanks)
    id_node = mods_xml.search("/mods:mods/mods:identifier").last
    n_id = Nokogiri::XML::Node.new "mods:identifier", mods_xml
    n_id.add_namespace_definition("mods", "http://www.loc.gov/mods/v3")
    n_id.content = arr[1][1]
    n_id.set_attribute("type", "ctsurn")
    id_node.add_next_sibling(n_id)

    w_arr = []
    unless p[:w_cts]
      w_hash = {:w_cts => w_cts, :title => p[:title], :lang => p[:w_lang], :name => p[:name]}
      w_arr = Form.build_work_info(w_hash)
    end
    tg_arr = []
    tg_cts = w_cts[/urn:cts:\w+:\w+/]
    tg_row = Textgroup.find_by_id(tg_cts)
    unless tg_row
      tg_hash = {:cts => tg_cts, :tg_name => p[:a_name], :name => p[:name]}
      tg_arr = Form.build_tg_info(tg_hash)
    end

    return mods_xml.to_xml, arr, w_arr, tg_arr
  end

  def self.copy_mods(p)
    #params: v_cts, v_label, v_desc, v_type, name, e_name, date, edition 
    vers = p[:v_cts]
    cts_parts = vers.split(':')
    id_parts = cts_parts[3].split('.')
    path = "#{BASE_DIR}/catalog_data/mods/#{cts_parts[2]}/#{id_parts[0]}/#{id_parts[1]}/#{id_parts[2]}/#{cts_parts[3]}.mods1.xml"
    #make new cite row
    v_row = Form.build_vers_info(p)
    mods_xml = Form.add_xml(path, p, v_row[1][1])   
    #need these to make it all work...
    w_arr = []
    tg_arr = []
    return mods_xml.to_xml, v_row, w_arr, tg_arr
  end

  def self.add_xml(path, p, urn)
    file_string = File.open(path, "r+")
    mods_xml = Nokogiri::XML::Document.parse(file_string, &:noblanks)
    file_string.close
    ns = mods_xml.namespaces
    
    #replace ctsurn
    id_node = mods_xml.xpath("//mods:identifier[@type='ctsurn']", ns)
    id_node.content = urn
    #add encoder sibling
    editor_node = mods_xml.xpath('mods:mods/mods:name', ns).last
    Nokogiri::XML::Builder.with(mods_xml.xpath('mods:mods', ns).last) do |xml|
      xml['mods'].name('xmlns:mods' => "http://www.loc.gov/mods/v3", :type => 'personal'){
        xml['mods'].namePart(p[:e_name])
        xml['mods'].role{
          xml['mods'].roleTerm(:authority => "marcrelator", :type => "text"){
            xml.text("encoder")
          }
        }
      }
    end
    n_name = mods_xml.xpath('mods:mods/mods:name', ns).last
    editor_node.add_next_sibling(n_name)
    #add originInfo/dateModified and edition
    Nokogiri::XML::Builder.with(mods_xml.xpath('//mods:originInfo', ns).last) do |xml|
      xml['mods'].dateModified('xmlns:mods' => "http://www.loc.gov/mods/v3"){
        xml.text(p[:date])
      }
    end

    ed_node = mods_xml.search("//mods:edition").last
    if ed_node
      ed_node.content = p[:edition]
    else
      Nokogiri::XML::Builder.with(mods_xml.xpath('//mods:originInfo', ns).last) do |xml|
        xml['mods'].edition('xmlns:mods' => "http://www.loc.gov/mods/v3"){
        xml.text(p[:edition])
      }
      end
    end
    #add subTitle of "Epidoc Edition" if edition == Epidoc
    if p[:edition] =~ /epidoc/i
      Nokogiri::XML::Builder.with(mods_xml.xpath("mods:titleInfo[@type='uniform']", ns).last) do |xml|
        xml['mods'].subTitle('xmlns:mods' => "http://www.loc.gov/mods/v3"){
          xml.text("Epidoc Edition")
        }
      end
    end
    return mods_xml
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
    #add cite urn
    v_arr = Form.build_auth_info(p)
    mads_xml = Nokogiri::XML::Document.parse(mads_xml, &:noblanks)
    id_node = mads_xml.search(".//identifier").last
    Nokogiri::XML::Builder.with(id_node) do |xml|
      xml['mads'].identifier('xmlns:mads' => "http://www.loc.gov/mads/v2", :type => "citeurn"){
        xml.text(v_arr[1][0])
      }
    end
    return mads_xml.to_xml, v_arr
  end

  def self.build_auth_info(p)
    #"urn", "authority_name", "canonical_id", "mads_file", "alt_ids", "related_works", 
    #"urn_status", "redirect_to", "created_by", "edited_by"
    auth_info = [["urn", "authority_name", "canonical_id", "mads_file", "alt_ids", "related_works", "urn_status", "redirect_to", "created_by", "edited_by"]]
    cite_urn = Author.generate_urn
    auth_info << [cite_urn, p[:a_name], p[:p_id], "", p[:alt_id], p[:rel_w], "reserved", "", p[:name], ""]
  end

  
  def self.arrayify(string)
    step = string.split('",')
    re_arr = step.each{|x| x.gsub!(/\[|"| "|\]/, '')}
  end


  def self.mini_cts_tg(row_arr)
    #taking in a tg row array
    projid = row_arr[1][/\w+:\w+$/]
    tg_cts = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |new_cts|
      new_cts.textgroup('xmlns:ti' => "http://chs.harvard.edu/xmlns/cts/ti", :projid => projid, :urn => row_arr[1]) {
        new_cts.parent.namespace = new_cts.parent.namespace_definitions.find{|ns|ns.prefix=="ti"}
        new_cts['ti'].textgroup(row_arr[2])
      }
    end
    return tg_cts.to_xml
  end


  def self.mini_cts_work(row_arr)
    #taking in a version row array
    urn = row_arr[1]
    w_projid = urn[/\w+:\w+\.\w+/].gsub(/:\w+\./, ":")
    g_urn = urn[/urn:cts:\w+:\w+/]
    work = Work.find_by_id(urn[/urn:cts:\w+:\w+\.\w+/])
    e_projid = urn[/\w+:\w+\..+$/].gsub(/:\w+\.\w+\./, ":")
    work_cts = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |new_cts|
      new_cts.work('xmlns:ti' => "http://chs.harvard.edu/xmlns/cts/ti", :groupUrn => g_urn, 
        :projid => w_projid, :urn => urn, 'xml:lang' => work.orig_lang){
        new_cts.parent.namespace = new_cts.parent.namespace_definitions.find{|ns|ns.prefix=="ti"}
        new_cts['ti'].title('xml:lang' => 'eng'){
          new_cts.text(work.title_eng)
        }
        #could try to abstract these, but it too much of a pain with the builder...
        if row_arr[4] == "edition"
          new_cts['ti'].edition(:projid => e_projid){
            new_cts['ti'].label("xml:lang" => "en"){
              new_cts.text(row_arr[2])
            }
            new_cts['ti'].description("xml:lang" => "en"){
              new_cts.text(row_arr[3])
            }
            if e_projid =~ /perseus/
              new_cts['ti'].memberOf(:collection => "Perseus:collection:Greco-Roman")
            end
          }
        else
          new_cts['ti'].translation(:projid => e_projid){
            new_cts['ti'].label("xml:lang" => "en"){
              new_cts.text(row_arr[2])
            }
            new_cts['ti'].description("xml:lang" => "en"){
              new_cts.text(row_arr[3])
            }
            if e_projid =~ /perseus/
              new_cts['ti'].memberOf(:collection => "Perseus:collection:Greco-Roman")
            end
          }
        end
      }
    end
    return work_cts.to_xml
  end

end

