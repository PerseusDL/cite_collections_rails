class Version < ActiveRecord::Base
  belongs_to :work
  
  def self.latest_urn
    latest_urn = Version.last['urn']
  end

  def self.generate_urn
    last_urn = Version.latest_urn
    unless last_urn
      new_urn = "urn:cite:perseus:catver.1.1"
    else
      urn_parts = last_urn.split('.')
      inc_urn = urn_parts[1].to_i + 1
      new_urn = "urn:cite:perseus:catver.#{inc_urn}.1"
    end
  end

  def self.cts_num_incr(existing_vers, v_cts_no_num)
    num = nil
    existing_vers.each do |line|
      curr_urn = line[:version][/#{v_cts_no_num}\d+/]
      urn_num = curr_urn[/\d+$/].to_i
      num = urn_num + 1
    end
    return num
  end

  def self.find_by_cts(id)
    found_ids = Version.find(:all, :conditions => ["version rlike ?", id])
  end

  def self.update_row(cts, vers_label, vers_desc, editor, has_mods=false, status="")
    vers = Version.find_by_cts(cts)[0]
    v_hash = {}            
    v_hash[:label_eng] = vers_label if vers.label_eng != vers_label
    v_hash[:desc_eng] = vers_desc if vers.desc_eng != vers_desc
    v_hash[:has_mods] = "true" if has_mods
    v_hash[:urn_status] = status if status != ""
    unless v_hash.empty?
      v_hash[:edited_by] = editor
      Version.update(vers.id, v_hash)
    end
  end

  def self.add_cite_row(v)
    #0urn, 1version, 2label_eng, 3desc_eng, 4type, 5has_mods, 6urn_status, 
    #7redirect_to, 8member_of, 9created_by, 10edited_by
    vers = Version.new do |vr|
      vr.urn = v[0]
      vr.version = v[1]
      vr.label_eng = v[2]
      vr.desc_eng = v[3] 
      vr.ver_type = v[4] 
      vr.has_mods = v[5]
      vr.urn_status = v[6] 
      vr.redirect_to = v[7]
      vr.member_of = v[8]
      vr.created_by = v[9]
      vr.edited_by = v[10]
      vr.source_urn = v[11]
    end
    vers.save
  end

  def self.lookup(params)
    type = params[:field_type]
    search = params[:search]
    valid_cols = ['urn', 'version', 'label_eng', 'desc_eng', 'type', 'has_mods', 'urn_status', 'redirect_to', 'member_of', 'created_by', 'edited_by']
    if valid_cols.include?(type)
      result = Version.all(:conditions => ["#{type} rlike ?", search])
    else
      result = nil
    end
  end

  def prev
    unless self.id == 1
      prev = Version.find(self.id - 1)
    else
      prev = nil
    end
    return prev
  end

  def next
    unless self.id == Version.last.id
      nxt = Version.find(self.id + 1)
    else
      nxt = nil
    end
    return nxt
  end

  def prevnext
    prev = self.prev
    nxt = self.next
    return prev, nxt
  end

end
