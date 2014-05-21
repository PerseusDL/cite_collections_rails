class Version < ActiveRecord::Base

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

  def self.find_by_cts(id)
    found_ids = Version.find(:all, :conditions => ["version rlike ?", id])
  end

  def self.update_row(id, hash)
    updated = Version.update(id, hash)
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
    end
    vers.save
  end

end
