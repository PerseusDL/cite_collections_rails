json.array!(@works) do |work|
  json.extract! work, :id, :urn, :work, :title_eng, :notes, :urn_status, :created_by, :edited_by
  json.url work_url(work, format: :json)
end
