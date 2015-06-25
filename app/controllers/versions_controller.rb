class VersionsController < ApplicationController
  before_filter :authenticate, except: [:show, :index, :search]
  before_action :set_version, only: [:show, :edit, :update, :destroy]

  # GET /versions
  # GET /versions.json
  def index
    session[:search_results] = request.url
    if request.url =~ /json/
      @versions = Version.where(urn_status: ["published", "reserved"])
    else
      @versions = Version.paginate(page: params[:page], per_page: 200)
      respond_to do |format|
        format.html
        format.js
      end
    end
  end

  # GET /versions/1
  # GET /versions/1.json
  def show
  end

  # GET /versions/new
  def new
    @version = Version.new
  end

  # GET /versions/1/edit
  def edit
  end

  # POST /versions
  # POST /versions.json
  def create
    @version = Version.new(version_params)

    respond_to do |format|
      if @version.save
        format.html { redirect_to @version, notice: 'Version was successfully created.' }
        format.json { render action: 'show', status: :created, location: @version }
      else
        format.html { render action: 'new' }
        format.json { render json: @version.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /versions/1
  # PATCH/PUT /versions/1.json
  def update
    respond_to do |format|
      if @version.update(version_params)
        format.html { redirect_to version_path(@version.urn), notice: 'Version was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @version.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /versions/1
  # DELETE /versions/1.json
  def destroy
    @version.destroy
    respond_to do |format|
      format.html { redirect_to versions_url }
      format.json { head :no_content }
    end
  end

  def search
    session[:search_results] = request.url
    @versions = Version.lookup(params)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_version
      @version = Version.find_by_urn(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def version_params
      params.require(:version).permit(:urn, :version, :label_eng, :desc_eng, :ver_type, :has_mods, :urn_status, :redirect_to, :member_of, :created_by, :edited_by)
    end
end
