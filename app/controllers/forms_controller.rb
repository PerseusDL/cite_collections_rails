class FormsController < ApplicationController
  respond_to :json, :html, :xml 
  #before_filter :authenticate
  def index
    
  end

  def show
  end

  def new
    @form = Form.new
  end

  def edit
  end

  def create
    re_arr = Form.arrayify(params[:arr])
    if params[:commit] == "Create Row"    
      @new_row = Form.build_row(re_arr)
    end
    if params[:commit] == "Create File"
      if params[:mods]
        unless params[:w_arr] == ""
          n_arr = Form.arrayify(params[:w_arr])
          @new_w = Form.build_work_row(n_arr)
        end

        unless params[:tg_arr] == ""
          tg_arr = Form.arrayify(params[:tg_arr])
          @new_tg = Form.build_tg_row(tg_arr)
          @tg_cts = Form.mini_cts_tg(tg_arr)
        end
        @new_row = Form.build_row(re_arr)
        #save mods record to catalog_pending
        @path = Form.save_xml(params[:mods], re_arr)
        @v_cts = Form.mini_cts_work(re_arr)
      elsif params[:mads]
        @new_a = Form.build_auth_row(re_arr)
        @path = Form.save_xml(params[:mads], re_arr)
      end 
    end
  end

  def search
    @s_res = Form.search(params)
  end

  def reserve
    if params[:obj]
      obj = params[:obj]
      if obj =~ /catwk/
        #new edition of work
        @w_row = Work.find_by_urn(obj)
      elsif obj =~ /catver/
        #reproducing an existing version
        @v_row = Version.find_by_urn(obj)
      else
        #something is wrong
      end
    elsif params[:commit] == "Reserve URN"
      #need to go back and add confirmation for values
      @v_arr = Form.build_vers_info(params)
    end
  end

  def mods
    if params[:obj]
      obj = params[:obj]
      if obj =~ /catwk/
        #new edition of work
        @w_row = Work.find_by_urn(obj)
      elsif obj =~ /catver/
        #reproducing an existing version
        @vers_row = Version.find_by_urn(obj)
        
      end
    elsif params["commit"] == "Create MODS"
      @mods, @v_arr, @w_arr, @tg_arr = Form.mods_creation(params)
    elsif params["commit"] == "Copy MODS"
      @mods, @v_arr, @w_arr, @tg_arr = Form.copy_mods(params)
    end
  end

  def mads
    if params[:commit] == "Create MADS"
      @mads, @a_arr = Form.mads_creation(params)
    end
  end
end
