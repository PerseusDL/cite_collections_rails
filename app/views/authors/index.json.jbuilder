json.array!(@authors) do |author|
  json.extract! author, :id, :urn, :authority_name, :canonical_id, :mads_file, :alt_ids, :related_works, :urn_status, :redirect_to, :created_by, :edited_by
  json.url author_url(author, format: :json)
end
