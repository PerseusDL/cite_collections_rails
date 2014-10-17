module Api
  class AuthorsController < ApplicationController
    respond_to :json, :xml
    before_action :set_author, only: [:show, :previous, :next, :prevnext]

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

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_author
          @author = Author.find_by_urn(params[:id])
      end
    end
end
