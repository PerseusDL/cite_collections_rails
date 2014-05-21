#rake tasks

desc "import records in catalog_pending"
task :catalog_pending_import => :environment do
  cpi = PendingRecordImporter.new
  cpi.import
end