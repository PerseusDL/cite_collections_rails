class TextgroupsController < ApplicationController
  before_filter :authenticate, except: [:show, :index, :search]
  before_action :set_textgroup, only: [:show, :edit, :update, :destroy]

  # GET /textgroups
  # GET /textgroups.json
  def index
    session[:search_results] = request.url
    @textgroups = Textgroup.all
  end

  # GET /textgroups/1
  # GET /textgroups/1.json
  def show
  end

  # GET /textgroups/new
  def new
    @textgroup = Textgroup.new
  end

  # GET /textgroups/1/edit
  def edit
  end

  # POST /textgroups
  # POST /textgroups.json
  def create
    @textgroup = Textgroup.new(textgroup_params)

    respond_to do |format|
      if @textgroup.save
        format.html { redirect_to @textgroup, notice: 'Textgroup was successfully created.' }
        format.json { render action: 'show', status: :created, location: @textgroup }
      else
        format.html { render action: 'new' }
        format.json { render json: @textgroup.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /textgroups/1
  # PATCH/PUT /textgroups/1.json
  def update
    respond_to do |format|
      if @textgroup.update(textgroup_params)
        format.html { redirect_to @textgroup, notice: 'Textgroup was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @textgroup.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /textgroups/1
  # DELETE /textgroups/1.json
  def destroy
    @textgroup.destroy
    respond_to do |format|
      format.html { redirect_to textgroups_url }
      format.json { head :no_content }
    end
  end

  def search
    session[:search_results] = request.url
    @textgroups = Textgroup.lookup(params)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_textgroup
      @textgroup = Textgroup.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def textgroup_params
      params.require(:textgroup).permit(:urn, :textgroup, :groupname_eng, :has_mads, :mads_possible, :notes, :urn_status, :redirect_to, :created_by, :edited_by)
    end
end
