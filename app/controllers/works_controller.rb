class WorksController < ApplicationController
  before_filter :authenticate, except: [:show, :index, :search]
  before_action :set_work, only: [:show, :edit, :update, :destroy]

  # GET /works
  # GET /works.json
  def index
    session[:search_results] = request.url
    @works = Work.where(urn_status: "published").load
  end

  # GET /works/1
  # GET /works/1.json
  def show
  end

  # GET /works/new
  def new
    @work = Work.new
  end

  # GET /works/1/edit
  def edit
  end

  # POST /works
  # POST /works.json
  def create
    @work = Work.new(work_params)

    respond_to do |format|
      if @work.save
        format.html { redirect_to work_path(@work.urn), notice: 'Work was successfully created.' }
        format.json { render action: 'show', status: :created, location: @work }
      else
        format.html { render action: 'new' }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /works/1
  # PATCH/PUT /works/1.json
  def update
    respond_to do |format|
      if @work.update(work_params)
        format.html { redirect_to @work, notice: 'Work was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /works/1
  # DELETE /works/1.json
  def destroy
    @work.destroy
    respond_to do |format|
      format.html { redirect_to works_url }
      format.json { head :no_content }
    end
  end

  def search
    session[:search_results] = request.url
    @works = Work.lookup(params)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_work
      @work = Work.find_by_urn(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def work_params
      params.require(:work).permit(:urn, :work, :title_eng, :orig_lang, :notes, :urn_status, :redirect_to, :created_by, :edited_by)
    end
end
