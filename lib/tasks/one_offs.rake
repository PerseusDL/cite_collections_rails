#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

#one-off rake tasks needed for making either the google fusion data what we need
#or updating that data to reflect the records more accurately

desc "mads path correction"
task :mads_path_change => :environment do
  of = OneOffs.new
  of.mads_path_change
end

desc "mads related work adder"
task :mads_related_works => :environment do
  of = OneOffs.new
  of.mads_rel_works  

end


desc "add column to work table"
task :add_orig_lang => :environment do
  collect = ""
  file = File.open("#{BASE_DIR}/cite_collections_rails/data/Perseus Work Collection.csv", "r")
  file.each_line do |line|
    row = line.split(/(,)(?=(?:[^"]|"[^"]*")*$)/)
    row.delete(",")
    lang = row[1] =~ /tlg/ ? "grc" : "lat"
    row.insert(3, lang)
    collect << row.join(",")
  end
  File.open("#{BASE_DIR}/cite_collections_rails/data/Perseus Work Collection.csv", "w") {|f| f << collect}
end

desc "remove cts-urn"
task :remove_cts_urn => :environment do
  Dir.glob("/#{BASE_DIR}/catalog_data/**/*.xml") do |file_name|
    text = File.read(file_name)
    if text =~ /cts-urn/
      replace = text.gsub!("cts-urn", "ctsurn")
      File.open(file_name, "w") { |file| file.puts replace }
    end
  end
  Dir.glob("/#{BASE_DIR}/catalog_pending/**/*.xml") do |file_name|
    text = File.read(file_name)
    if text =~ /cts-urn/
      replace = text.gsub!("cts-urn", "ctsurn")
      File.open(file_name, "w") { |file| file.puts replace }
    end
  end
end
