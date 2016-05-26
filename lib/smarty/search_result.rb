module Smarty
  class SearchResult
    attr_reader :question, :score

    def initialize(attrs = {})
      @question = attrs[:question]
      @score    = attrs[:score]
    end
  end
end
