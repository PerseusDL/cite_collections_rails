#Copyright 2014 The Perseus Project, Tufts University, Medford MA
#This free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
#published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#See http://www.gnu.org/licenses/.
#=============================================================================================

#Atom build rake tasks

desc "Build Atom feed"
task :build_atom_feed => :environment do
  builder = AtomBuild.new
  #types are 'all' or 'latest'
  type = ENV["type"]
  builder.set_up_feeds(type)
  #would like to add in passing a variable of just the recently changed records 
  #in the CITE tables, but becomes extremely complex for managing authors, so leaving it for now
end