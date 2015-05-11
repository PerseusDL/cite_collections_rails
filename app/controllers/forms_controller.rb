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
    if params[:commit] == "Create Row"
      re_arr = params[:arr].gsub(/\[|"| "|\]/, '').split(',')
      @new_row = Form.build_row(re_arr)
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
    if params["commit"] == "Create MODS"
      @mods = Form.mods_creation(params)
    end
  end
end
