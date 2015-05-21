class MadsRecordBuilder
  require 'nokogiri'
  include ApplicationHelper

  def mads_builder(line_arr)

    #0authority name, 1authority term of address, 2authority dates, 3alt names(parts sep by ;, multi names sep by |),
    #4main identifier, 5id type, 6alt ids, 7source note, 8field of activity, 
    #9urls, 10related works
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |new_mads|
      new_mads.mads('xmlns:mads' => "http://www.loc.gov/mads/v2",
            'xmlns:mods' => "http://www.loc.gov/mods/v3", 
            'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
            'xmlns:xlink' => "http://www.w3.org/1999/xlink",
            'xsi:schemaLocation' => "http://www.loc.gov/mads/ http://www.loc.gov/standards/mads/mads.xsd http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-2.xsd",
            :version => "2.0"){
      new_mads.parent.namespace = new_mads.parent.namespace_definitions.find{|ns|ns.prefix == "mads"}

      #authority name
      #0authority name, 1authority term of address, 2authority dates,
      new_mads['mads'].authority{
        new_mads['mads'].name(:type => 'personal'){
          new_mads['mads'].namePart(line_arr[0])
          #term of address
          unless line_arr[1] == ""
            new_mads['mads'].namePart(:type => "termsOfAddress"){
              new_mads.text(line_arr[1])
            }
          end
          #dates
          unless line_arr[2] == ""
            new_mads['mads'].namePart(:type => "date"){
              new_mads.text(line_arr[2])
            }
          end
        }
      }

      #variant names, potentially multiple, need each 
      #3alt names(parts sep by ;, multi names sep by |),
      unless line_arr[3] == ""
        line_arr[3].split("|").each do |a_name|
          a_parts = a_name.split(";")
          #parts 0alt name, 1alt_lang, 2alt_t_o_a, 3alt_a_dates
          new_mads['mads'].variant(:type => 'other', :lang => "#{a_parts[1]}"){
            new_mads['mads'].name(:type => 'personal'){
              new_mads['mads'].namePart(a_parts[0])
              unless a_parts[2] == ""
                new_mads['mads'].namePart(:type => "termsOfAddress"){
                  new_mads.text(a_parts[2])
                }
              end
              #dates
              unless a_parts[3] == ""
                new_mads['mads'].namePart(:type => "date"){
                  new_mads.text(a_parts[3])
                }
              end
            }
          }
        end
      end

      #identifier
      #4main identifier, 5id type, 6alt ids
      new_mads['mads'].identifier(:type => "#{line_arr[5]}"){
        new_mads.text(line_arr[4])
      }
      #each statement for other ids
      line_arr[6].split("|").each do |alts|
        alts_parts = alts.split(";")
        new_mads['mads'].identifier(:type => "#{alts_parts[1]}"){
          new_mads.text(alts_parts[0])
        }
      end

      #source note (potential each for multiple)
      unless line_arr[7] == ""
        new_mads['mads'].note(:type => 'source'){
          new_mads.text(line_arr[7])
        }
      end
        
      #field of activity, add unless empty
      unless line_arr[8] == ""
        new_mads['mads'].fieldOfActivity{
          new_mads.text(line_arr[8])
        }
      end

      #urls, need each statement
      line_arr[9].split("|").each do |urls|
        u_parts = urls.split(";")
        new_mads['mads'].url(:displayLabel => "#{u_parts[1]}"){
          new_mads.text(u_parts[0])
        }
      end

      #related works, each statement within extension
      line_arr[10].split("|").each do |wrk|
        parts = wrk.split(";")
        new_mads['mads'].extension{
          new_mads['mads'].description("List of related work identifiers")
          new_mads.identifier(:type => "#{parts[1]}"){
            new_mads.text(parts[0])
          }
        }
      end
      }    
    end
    return builder.to_xml
  end
end