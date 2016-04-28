module Smarty
  class Question

    attr_accessor :link, :text

    def initialize(link:, text:)
      @link = link
      @text = text
    end

    def self.search(text)
      [ Question.new(link: "https://carbonfive.slack.com/archives/codeo/p1461863849000033", text: "What is the Codeo?") ]
    end

    def save

    end

  end
end
