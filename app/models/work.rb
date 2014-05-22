class Work < ActiveRecord::Base

  def self.latest_urn
    latest_urn = Work.last['urn']
  end

  def self.generate_urn
    last_urn = Work.latest_urn
    unless last_urn
      new_urn = "urn:cite:perseus:catwk.1.1"
    else
      urn_parts = last_urn.split('.')
      inc_urn = urn_parts[1].to_i + 1
      new_urn = "urn:cite:perseus:catwk.#{inc_urn}.1"
    end
  end

  def self.find_by_id(id)
    found_id = Work.find_by_work(id)
  end

  def self.add_cite_row(v)
    #0urn, 1work, 2title_eng, 3orig_lang, 4notes, 5urn_status, 6created_by, 7edited_by
    wrk = Work.new do |w|
      w.urn = v[0]
      w.work = v[1]
      w.title_eng = v[2]
      w.orig_lang = v[3]
      w.notes = v[4]
      w.urn_status = v[5] 
      w.created_by = v[6]
      w.edited_by = v[7]
    end
    wrk.save
  end

end
