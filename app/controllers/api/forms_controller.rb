module Api
  class FormsController < ApplicationController
    respond_to :json, :xml
    before_filter :default_format_xml

    def default_format_xml
      request.format = "xml" unless params[:format]
    end

    def show

    end

    def reserve
      received = params.permit() 
      #reserve version rows
      #have work and tg in tables
        #copy pre-existing
          #need version urn and name of user
        #new edition entirely
          #need ed/trans?, language, perseus?, user name 
      
      #don't have work and tg in tables
        #new edition entirely
          #need to reserve tg, work, and version rows
      
      query = []
      #change query to appropriate string, keeping here for the sanitize function 
      received.each {|k, v| query << "#{k} rlike #{ActiveRecord::Base.sanitize("#{v}")}"}
    end
  end
end