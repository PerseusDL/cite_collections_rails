module Api
  class AuthorsController < ApplicationController
    respond_to :json, :xml
    before_action :set_author, only: [:show, :previous, :next, :prevnext]
    before_filter :default_format_xml

    def default_format_xml
      request.format = "xml" unless params[:format]
    end

    def index
      @authors = Author.all
      respond_with(@authors, except: :id)
    end

    def show
      respond_with(@author, except: :id)
    end

    def count     
      c = Author.count
      @count = {:collection_size => c}
      respond_with(@count)
    end

    def first
      @first = Author.first
      respond_with(@first, except: :id)
    end

    def last
      @last = Author.last
      respond_with(@last, except: :id)
    end

    def previous
      @prev = @author.prev
      respond_with(@prev, except: :id)
    end

    def next
      @next = @author.next
      respond_with(@next, except: :id)
    end

    def prevnext
      @prev, @next = @author.prevnext
      @both = {:previous => @prev, :next => @next}
      respond_with(@both, except: :id)
    end

    def search
      received = params.permit(:urn, :authority_name, :canonical_id, :mads_file, :alt_ids, :related_works, :urn_status, :redirect_to, :created_by, :edited_by) 
      query = []
      received.each {|k, v| query << "#{k} rlike #{ActiveRecord::Base.sanitize("#{v}")}"}
      if params.key?("canonical_id") && params.key?("alt_ids")
        query_string = query.join(" OR ")
      else
        query_string = query.join(" AND ")
      end
      @response = Author.where(query_string)
      respond_with(@response, except: :id)
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_author
          @author = Author.find_by_urn(params[:id])
      end
    end
end
