module Api
  class TextgroupsController < ApplicationController
    respond_to :json, :xml
    before_action :set_textgroup, only: [:show, :previous, :next, :prevnext]
    before_filter :default_format_xml

    def default_format_xml
      request.format = "xml" unless params[:format]
    end
    
    def index
      @textgroups = Textgroup.all
      respond_with(@textgroups, except: :id)
    end

    def show
      respond_with(@textgroup, except: :id)
    end

    def count     
      c = Textgroup.count
      @count = {:collection_size => c}
      respond_with(@count)
    end

    def first
      @first = Textgroup.first
      respond_with(@first, except: :id)
    end

    def last
      @last = Textgroup.last
      respond_with(@last, except: :id)
    end

    def previous
      @prev = @textgroup.prev
      respond_with(@prev, except: :id)
    end

    def next
      @next = @textgroup.next
      respond_with(@next, except: :id)
    end

    def prevnext
      @prev, @next = @textgroup.prevnext
      @both = {:previous => @prev, :next => @next}
      respond_with(@both, except: :id)
    end

    def search
      received = params.permit(:urn, :textgroup, :groupname_eng, :has_mads, :mads_possible, :notes, :urn_status, :redirect_to, :created_by, :edited_by)
      query = []
      received.each  {|k, v| query << "#{k} rlike #{ActiveRecord::Base.sanitize("#{v}")}"}
      @response = Textgroup.where(query.join(" AND "))
      respond_with(@response, except: :id)
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_textgroup
          @textgroup = Textgroup.find_by_urn(params[:id])
      end
    end
end
