class SongsController < ApplicationController
  include Pagy::Backend

  def index
    @q = params['song'] && params['song']['q']

    hits         = Song.includes(:author).pagy_search(@q, limit: 100)
    @pagy, @hits = pagy_meilisearch(hits, items: 1)
  end
end
