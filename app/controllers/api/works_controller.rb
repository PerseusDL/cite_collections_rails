module Api
  class WorksController < ApplicationController
    respond_to :json, :xml
    before_action :set_work, only: [:show, :previous, :next, :prevnext]

    def index
      @works = Work.all
      respond_with(@works, except: :id)
    end

    def show
      respond_with(@work, except: :id)
    end

    def count     
      c = Work.count
      @count = {:collection_size => c}
      respond_with(@count)
    end

    def first
      @first = Work.first
      respond_with(@first, except: :id)
    end

    def last
      @last = Work.last
      respond_with(@last, except: :id)
    end

    def previous
      @prev = @work.prev
      respond_with(@prev, except: :id)
    end

    def next
      @next = @work.next
      respond_with(@next, except: :id)
    end

    def prevnext
      @prev, @next = @work.prevnext
      @both = {:previous => @prev, :next => @next}
      respond_with(@both, except: :id)
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_work
          @work = Work.find_by_urn(params[:id])
      end
    end
end
