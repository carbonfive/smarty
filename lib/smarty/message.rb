module Smarty
  module Message
    def question?
      self.text.split(' ').length >= 5 && self.text =~ /\?/
    end
  end
end
