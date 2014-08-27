#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

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

desc "one time mads path correction"
task :mads_path_change => :environment do
  pri = PendingRecordImporter.new
  pri.mads_path_change

end