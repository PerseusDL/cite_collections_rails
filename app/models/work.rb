class Work < ActiveRecord::Base
  has_many :versions
  belongs_to :textgroup

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

  def self.update_row(info_hash, editor)
    work = info_hash[:cite_work]
    w_hash = {}
    if work.title_eng != info_hash[:w_title]
      w_hash[:title_eng] = info_hash[:w_title]
      w_hash[:edited_by] = editor
    end
    unless work.orig_lang
      w_hash[:orig_lang] = info_hash[:w_lang]
    end
    Work.update(work.id, w_hash) unless w_hash.empty?
  end

  def self.add_cite_row(v)
    #0urn, 1work, 2title_eng, 3orig_lang, 4notes, 5urn_status, 6redirect_to, 7created_by, 8edited_by
    wrk = Work.new do |w|
      w.urn = v[0]
      w.work = v[1]
      w.title_eng = v[2]
      w.orig_lang = v[3]
      w.notes = v[4]
      w.urn_status = v[5]
      w.redirect_to = v[6] 
      w.created_by = v[7]
      w.edited_by = v[8]
    end
    wrk.save
  end

  def self.lookup(params)
    type = params[:field_type]
    search = params[:search]
    valid_cols = ['urn', 'work', 'title_eng', 'orig_lang', 'notes', 'urn_status', 'redirect_to', 'created_by', 'edited_by']
    if valid_cols.include?(type)
      result = Work.all(:conditions => ["#{type} rlike ?", search])
    else
      result = nil
    end
  end

  def prev
    unless self.id == 1
      prev = Work.find(self.id - 1)
    else
      prev = nil
    end
    return prev
  end

  def next
    unless self.id == Work.last.id
      nxt = Work.find(self.id + 1)
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
