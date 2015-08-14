module Api
  class FormsController < ApplicationController
    respond_to :json, :xml
    before_filter :default_format_xml

    def default_format_xml
      request.format = "xml" unless params[:format]
    end

    def show

    end

    def reserve(input)
      #params => id, type = (existing, newVers, newWork), user
      params = {}
      params = JSON.parse(input,:symbolize_names => true)
      received = params.permit()
      query = [] 
      #reserve version rows
      #have work and tg in tables
      if params[:type] == "existing"
        #copy pre-existing
        row = Version.where("version = #{ActiveRecord::Base.sanitize("#{params[:id]}")}")
          #need version urn and name of user
        #new edition entirely
      elsif params[:type] == "newVers"
          #need ed/trans?, language, perseus?, user name 
      
      #don't have work in tables
      elsif params[:type] == "newWork"
        
        #new edition entirely
          #need to reserve tg, work, and version rows
      end
      
      #change query to appropriate string, keeping here for the sanitize function 
      received.each {|k, v| query << "#{k} rlike #{ActiveRecord::Base.sanitize("#{v}")}"}

      #should return cts and cite urns
    end

    def mods(input)
      #params should be a hash of the mods csv plus any other useful fields (user, source of the request?)
      params = {}
      params = JSON.parse(input,:symbolize_names => true)
      @mods, v_arr, w_arr, tg_arr = Form.mods_creation(params)
      unless w_arr[1] == ""
        @new_w = Form.build_work_row(w_arr[1])
      end
      unless tg_arr[1] == ""
        @new_tg = Form.build_tg_row(tg_arr[1])
        @tg_cts = Form.mini_cts_tg(tg_arr[1])
      end
      @new_row = Form.build_row(v_arr[1])
      #save mods record to catalog_pending
      @path = Form.save_xml(@mods, v_arr[1])
      @v_cts = Form.mini_cts_work(v_arr[1])
    end
  end
end