class Author < ActiveRecord::Base

  def self.latest_urn
    latest_urn = Author.last['urn']
  end

  def self.generate_urn
    last_urn = Author.latest_urn
    unless last_urn
      new_urn = "urn:cite:perseus:author.1.1"
    else
      urn_parts = last_urn.split('.')
      inc_urn = urn_parts[1].to_i + 1
      new_urn = "urn:cite:perseus:author.#{inc_urn}.1"
    end
  end

  def self.find_by_id(id)
    found_id = Author.find_by_canonical_id(id) 
    found_id = Author.find(:all, :conditions => ["alt_ids rlike ?", id]) unless found_id
  end

  def self.update_row(id, hash)
    updated = Author.update(id, hash)
  end

  def self.add_cite_row(v)
    #"0urn, 1authority_name, 2canonical_id, 3mads_file, 4alt_ids, 5related_works, 
    #6urn_status, 7redirect_to, 8created_by, 9edited_by"
    auth = Author.new do |a|
      a.urn = v[0]
      a.authority_name = v[1]
      a.canonical_id = v[2]
      a.mads_file = v[3] 
      a.alt_ids = v[4] 
      a.related_works = v[5]
      a.urn_status = v[6] 
      a.redirect_to = v[7] 
      a.created_by = v[8]
      a.edited_by = v[9]
    end
    auth.save
  end

  def self.lookup(params)
    type = params[:field_type]
    search = params[:search]
    valid_cols = ['urn', 'authority_name', 'canonical_id', 'mads_file', 'alt_ids', 'related_works', 'urn_status', 'redirect_to', 'created_by', 'edited_by']
    if valid_cols.include?(type)
      result = Author.all(:conditions => ["#{type} rlike ?", search])
    else
      result = nil
    end
  end

  def prev
    unless self.id == 1
      prev = Author.find(self.id - 1)
    else
      prev = nil
    end
    return prev
  end

  def next
    unless self.id == Author.last.id
      nxt = Author.find(self.id + 1)
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
