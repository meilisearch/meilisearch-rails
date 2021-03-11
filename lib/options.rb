# MeiliSearch settings
OPTIONS = [
    # Attributes
    :searchableAttributes, :attributesForFaceting, :unretrievableAttributes, :attributesToRetrieve,
    :attributesToIndex, #Legacy name of searchableAttributes
    # Ranking
    :ranking, :customRanking, # Replicas are handled via `add_replica`
    # Faceting
    :maxValuesPerFacet, :sortFacetValuesBy,
    # Highlighting / Snippeting
    :attributesToHighlight, :attributesToSnippet, :highlightPreTag, :highlightPostTag,
    :snippetEllipsisText, :restrictHighlightAndSnippetArrays,
    # Pagination
    :hitsPerPage, :paginationLimitedTo,
    # Typo
    :minWordSizefor1Typo, :minWordSizefor2Typos, :typoTolerance, :allowTyposOnNumericTokens,
    :disableTypoToleranceOnAttributes, :disableTypoToleranceOnWords, :separatorsToIndex,
    # Language
    :ignorePlurals, :removeStopWords, :camelCaseAttributes, :decompoundedAttributes,
    :keepDiacriticsOnCharacters, :queryLanguages, :indexLanguages,
    # Query Rules
    :enableRules,
    # Query Strategy
    :queryType, :removeWordsIfNoResults, :advancedSyntax, :optionalWords,
    :disablePrefixOnAttributes, :disableExactOnAttributes, :exactOnSingleWordQuery, :alternativesAsExact,
    # Performance
    :numericAttributesForFiltering, :allowCompressionOfIntegerArray,
    :numericAttributesToIndex, # Legacy name of numericAttributesForFiltering
    # Advanced
    :attributeForDistinct, :distinct, :replaceSynonymsInHighlight, :minProximity, :responseFields,
    :maxFacetHits,

    # Rails-specific
    :synonyms, :placeholders, :altCorrections,
  ]

  #MeiliSearch settings

  OPTIONS = [
      
  ]
