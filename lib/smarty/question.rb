module Smarty
  class Question

    attr_accessor :link, :text

    def initialize(link:, text:)
      @link = link
      @text = text
    end

    def self.search(text)
      [ Question.new("slack://somewhere", "---") ]
    end

    def save

    end

  end
end
