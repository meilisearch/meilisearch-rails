class SearchController < ApplicationController
    def index
        @q = params['book'] && params['book']['q']
        @hits = Book.search('') if @q.blank?

        @hits = Book.search(@q, { hitsPerPage: 5, page: (params['page'] || 1) })
    end    
end
