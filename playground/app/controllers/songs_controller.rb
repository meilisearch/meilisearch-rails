class SongsController < ApplicationController
  include Pagy::Backend

  def index
    @q = params['song'] && params['song']['q']

    hits         = Song.pagy_search(@q)
    @pagy, @hits = pagy_meilisearch(hits, items: 5)
  end
end
