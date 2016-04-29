module Smarty
  class Question
    INDEX = 'smarty'
    TYPE = 'question'

    attr_accessor :link, :text, :persisted

    def self.config=(config)
      @@config = config
    end

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

      puts "ES results: -->"
      p results
      SearchResponse.new(results)
    end

    def save
      return if persisted
      Question.client.index(index: INDEX, type: TYPE, body: {
        text: text,
        link: link
      })
    end

    def self.delete_index
      client.indices.delete(index: Question::INDEX) if client.indices.exists? index: Question::INDEX
    end

    def self.create_index
      puts "Using ES: #{@@config.es_client_url}"
      unless client.indices.exists? index: Question::INDEX
        client.indices.create index: Question::INDEX,
          body: {
            settings: {
              analysis: {
                analyzer: {
                  smarty_analyzer: {
                    type: 'standard',
                    stopwords: '_english_'
                  }
                }
              }
            },
            mappings: {
              document: {
                properties: {
                  text: { type: 'string', index: 'analyzed', analyzer: 'smarty_analyzer' },
                  link: { type: 'string', index: 'not_analyzed' }
                }
              }
            }
          }
      end
    end

    def self.seed
      Question.new(text: "what is the best integration testing tool (or what do you use) for node land",
                   link: "https://carbonfive.slack.com/archives/development/p1461090698000023").save
      Question.new(text: "What do we use to integration test node.js web apps? Like the equivalent of [RSpec/Cucumber] + Capybara?",
                   link: "https://carbonfive.slack.com/archives/development/p1441372330000073").save
      Question.new(text: "anyone know of a good integration testing library for java? Something that can support database level testing, including inserting fixtures and cleaning",
                   link: "https://carbonfive.slack.com/archives/development/p1449683048000011").save

      Question.new(text: "Apologies for not knowing this but is our code of conduct for events available online?",
                   link: "https://carbonfive.slack.com/archives/general/p1461282700000336").save
      Question.new(text: "Is the code of conduct printed online somewhere?",
                   link: "https://carbonfive.slack.com/archives/outreach/p1431493261000010").save

      Question.new(text: "will there be pizza?",
                   link: "https://carbonfive.slack.com/archives/design/p1460051102000015").save
      Question.new(text: "free pizza and beer? done!",
                   link: "https://carbonfive.slack.com/archives/la/p1445444925000008").save
      Question.new(text: "isn’t there supposed to be a rat with that pizza?",
                   link: "https://carbonfive.slack.com/archives/ny/p1453923134000025").save
      Question.new(text: "...also, has there been enough pizza?",
                   link: "https://carbonfive.slack.com/archives/la/p1447885503000061").save
    end

    private

    def self.client
      @@config.es
    end
  end
end
