module Smarty
  class Question
    INDEX = 'smarty'
    TYPE = 'question'

    attr_accessor :link, :text, :persisted

    def initialize(link:, text:, persisted: false)
      @link = link
      @text = text
      @persisted = persisted
    end

    # Returns an array of Questions
    def self.search(text)
      results = client.search({
        index: INDEX,
        body: {
          query: { match: { text: text } },
          size: 5
        }
      })

      SearchResponse.new(results)
    end

    def save
      return if persisted
      client.index(index: INDEX, type: TYPE, body: {
        text: text,
        link: link
      })
    end

    private

    def client
      Smarty::Config.es
    end
  end
end
