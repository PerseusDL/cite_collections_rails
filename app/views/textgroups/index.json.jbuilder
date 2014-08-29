json.array!(@textgroups) do |textgroup|
  json.extract! textgroup, :id, :urn, :textgroup, :groupname_eng, :has_mads, :mads_possible, :notes, :urn_status, :redirect_to, :created_by, :edited_by
  json.url textgroup_url(textgroup, format: :json)
end
