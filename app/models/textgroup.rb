class Textgroup < ActiveRecord::Base

  def self.latest_urn
    latest_urn = Textgroup.last['urn']
  end

  def self.generate_urn
    last_urn = Textgroup.latest_urn
    unless last_urn
      new_urn = "urn:cite:perseus:textgroup.1.1"
    else
      urn_parts = last_urn.split('.')
      inc_urn = urn_parts[1].to_i + 1
      new_urn = "urn:cite:perseus:textgroup.#{inc_urn}.1"
    end
  end

  def self.find_by_id(id)
    found_id = Textgroup.find_by_textgroup(id)
  end

  def self.update_row(id, hash)
    updated = Textgroup.update(id, hash)
  end
  
  def self.add_cite_row(v)
    #0urn, 1textgroup, 2groupname_eng, 3has_mads, 4mads_possible, 5notes, 
    #6urn_status, 7created_by, 8edited_by
    tg = Textgroup.new do |t|
      t.urn = v[0]
      t.textgroup = v[1]
      t.groupname_eng = v[2]
      t.has_mads = v[3] 
      t.mads_possible = v[4] 
      t.notes = v[5]
      t.urn_status = v[6] 
      t.created_by = v[7]
      t.edited_by = v[8]
    end
    tg.save
  end
end
