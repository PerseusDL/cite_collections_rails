class FormsController < ApplicationController
  respond_to :json, :html, :xml 
  #before_filter :authenticate
  def index
    unless params[:obj]
      #initial search
      @s_res = Form.search(params)
    else
      obj = params[:obj]
      if obj =~ /catwk/
        #new edition of work
        @w_row = Work.find_by_urn(obj)
      else
        #something is wrong...
      end
          
    end
    
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
  def reserve
    if params[:obj]
      obj = params[:obj]
      if obj =~ /catver/
        #reproducing an existing version
        v_row = Version.find_by_urn(obj)
        @v_arr = Form.build_vers_info(params, v_row)
      else
        #something is wrong
      end
    elsif params[:commit] == "Reserve URN"
      #need to go back and add confirmation for values
      @v_arr = Form.build_vers_info(params)
    end
  end
end
