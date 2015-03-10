json.array!(@versions) do |version|
  json.extract! version, :id, :urn, :version, :label_eng, :desc_eng, :ver_type, :has_mods, :urn_status, :redirect_to, :member_of, :created_by, :edited_by
  json.url version_url(version.urn, format: :json)
end
