require 'pagy/extras/meilisearch'
require 'pagy/extras/bootstrap'

Pagy::MeilisearchExtra::Backend.module_eval do
  def pagy_meilisearch(pagy_search_args, vars = {})
    model, term, options    = pagy_search_args
    vars                    = pagy_meilisearch_get_vars(nil, vars)
    options[:hits_per_page] = vars[:items]
    options[:page]          = vars[:page]
    results                 = model.send(:ms_search, term, **options)
    vars[:count]            = results.raw_answer['totalHits']

    pagy                 = ::Pagy.new(vars)

    # with :last_page overflow we need to re-run the method in order to get the hits
    return pagy_meilisearch(pagy_search_args, vars.merge(page: pagy.page)) \
            if defined?(::Pagy::OverflowExtra) && pagy.overflow? && pagy.vars[:overflow] == :last_page

    [pagy, results]
  end
end
