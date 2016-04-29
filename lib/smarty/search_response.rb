class SearchResponse
  include Enumerable
  extend Forwardable

  def_instance_delegators :@results, :each, :size, :length, :empty?

  def initialize(response_hash)
    @source = response_hash
    @results = SearchResponse.build_results(@source)
  end

  def self.build_results(source)
    if source['hits'] && source['hits'].key?('hits')
      source['hits']['hits'].map do |hash|
        source = hash['source']
        Question.new(text: source['text'], link: source['link'], persisted: true)
      end
    else
      []
    end
  end
end
