module Smarty
  module User
    def question=(question)
      @data['question'] = question
    end

    def question
      @data['question']
    end

    def step=(step)
      @data['step'] = step ? step.to_s : nil
    end

    def step
      step = @data['step']
      step ? step.to_sym : nil
    end

    def reset
      self.question = nil
      self.step = nil
    end
  end
end
