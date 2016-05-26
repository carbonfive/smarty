module Smarty
  class SearchResults
    include Enumerable
    extend Forwardable

    def_instance_delegators :@results, :each, :size, :length, :empty?

    attr_reader :query, :source

    def initialize(query, response)
      @query = query
      @source = response
      @results = SearchResults.build_results(@source)
    end

    def self.build_results(source)
      if source['hits'] && source['hits'].key?('hits')
        source['hits']['hits'].map do |hash|
          source = hash['_source']
          score  = hash['_score']
          question = Question.new(text: source['text'], link: source['link'], persisted: true)
          SearchResult.new(question: question, score: score)
        end
      else
        []
      end
    end
  end
end
