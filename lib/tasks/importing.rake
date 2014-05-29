#rake tasks

desc "import records in catalog_pending"
task :catalog_pending_import => :environment do
  #need option to specify who is editing?
  cpi = PendingRecordImporter.new
  cpi.import
end

desc "add column to work table"
task :add_orig_lang => :environment do
  collect = ""
  file = File.open("#{ENV['HOME']}/Downloads/Perseus Work Collection.csv", "r")
  file.each_line do |line|
    row = line.split(/(,)(?=(?:[^"]|"[^"]*")*$)/)
    row.delete(",")
    lang = row[1] =~ /tlg/ ? "grc" : "lat"
    row.insert(3, lang)
    collect << row.join(",")
  end
  File.open("#{ENV['HOME']}/Downloads/Perseus Work Collection1.csv", "w") {|f| f << collect}
end