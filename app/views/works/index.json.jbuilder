json.array!(@works) do |work|
  json.extract! work, :id, :urn, :work, :title_eng, :orig_lang, :notes, :urn_status, :created_by, :edited_by
  json.url work_url(work, format: :json)
end
