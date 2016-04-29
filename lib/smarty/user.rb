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

    def anonymous=(anonymous)
      @data['anonymous'] = anonymous
    end

    def anonymous?
      @data['anonymous']
    end

    def channel=(channel)
      @data['channel'] = channel
    end

    def channel
      @data['channel']
    end

    def reset
      @data = {}
    end
  end
end
