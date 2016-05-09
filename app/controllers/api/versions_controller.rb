module Api
  class VersionsController < ApplicationController
    respond_to :json, :xml
    before_action :set_version, only: [:show, :previous, :next, :prevnext]
    before_filter :default_format_xml

    def default_format_xml
      request.format = "xml" unless params[:format]
    end
    
    def index
      @versions = Version.all
      respond_with(@versions, except: :id)
    end

    def show
      respond_with(@version, except: :id)
    end

    def count     
      c = Version.count
      @count = {:collection_size => c}
      respond_with(@count)
    end

    def first
      @first = Version.first
      respond_with(@first, except: :id)
    end

    def last
      @last = Version.last
      respond_with(@last, except: :id)
    end

    def previous
      @prev = @version.prev
      respond_with(@prev, except: :id)
    end

    def next
      @next = @version.next
      respond_with(@next, except: :id)
    end

    def prevnext
      @prev, @next = @version.prevnext
      @both = {:previous => @prev, :next => @next}
      respond_with(@both, except: :id)
    end

    def search
      received = params.permit(:urn, :version, :label_eng, :desc_eng, :type, :has_mods, :urn_status, :redirect_to, :member_of, :created_by, :edited_by, :source_urn)
      #this allows for a bit of fuzzy searching, could input "tlg0012" and get back all works for it     
      query = []
      received.each  {|k, v| query << "#{k} rlike #{ActiveRecord::Base.sanitize("#{v}")}"}
      @response = Version.where(query.join(" AND "))
      respond_with(@response, except: :id)
    end

    def redirect
      # hack to handle records who have a source urn but have not been 
      # officially redirected yet
      @redirected = Version.where(:source_urn => params[:version])
      if @redirected.length == 0
        @response = Version.where(:version => params[:version])
        if (@response.length == 1) 
          if @response[0][:redirect_to] =~ /^urn:cite/
            @redirected = Version.where(:urn => @response[0][:redirect_to])
          elsif @response[0][:redirect_to] && @response[0][:redirect_to] =~ /^urn:cts/
            @redirected = Version.where(:version => @response[0][:redirect_to])
          else
            @redirected = @response[0]
          end
        end
      end
      #TODO this should resppond with a 404 if none found
      # and should responds with a 500? if > 1 found
      # and ideally would only ever return just the urn and not an array
      respond_with(@redirected, only: :version)
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_version
          @version = Version.find_by_urn(params[:id])
      end
    end
end
