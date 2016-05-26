module Smarty
  class Question
    INDEX = 'smarty'
    TYPE = 'question'
    STOPWORDS = ( "a able about across after all almost also am among an and any are as at be because been but by can cannot could dear " +
                  "did do does either else ever every for from get got had has have he her hers him his how however i if in into is it its " +
                  "just least let like likely may me might most must my neither no nor not of off often on only or other our own " +
                  "rather said say says she should since so some than that the their them then there these they this tis to too twas us " +
                  "wants was we were what when where which while who whom why will with would yet you your" ).split
    SETTINGS = {
      analysis: {
        analyzer: {
          smarty_analyzer: { type: 'snowball', stopwords: STOPWORDS }
        }
      }
    }

    attr_accessor :link, :text, :persisted

    def self.config=(config)
      @@config = config
    end

    def initialize(link:, text:, persisted: false)
      @link = link
      @text = text
      @persisted = persisted
    end

    def self.search(text)
      response = client.search({
        index: INDEX,
        body: {
          query: { match: { text: text } },
          size: 5,
          min_score: 0.01
        }
      })

      results = SearchResults.new(text, response)
      puts "Search -> #{results.query}"
      results.each do |result|
        puts "[ #{result.score} ] - #{result.question.text}"
      end
      results
    end

    def save
      return if persisted
      puts "Save question: #{text}"
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
      if client.indices.exists? index: Question::INDEX
        return false
      else
        client.indices.create index: Question::INDEX,
          body: {
            settings: SETTINGS,
            mappings: {
              document: {
                properties: {
                  text: { type: 'string', index: 'analyzed', analyzer: 'smarty_analyzer' },
                  link: { type: 'string', index: 'not_analyzed' }
                }
              }
            }
          }
        return true
      end
    end

    def self.update_index
      client.indices.close        index: Question::INDEX
      client.indices.put_settings index: Question::INDEX, body: { index: SETTINGS }
      client.indices.open         index: Question::INDEX
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
