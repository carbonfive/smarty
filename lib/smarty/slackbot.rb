module Smarty
  class Slackbot
    def initialize(bot)
      Slacky::User.decorator = User

      @config = bot.config
      @config.extend Config

      @bot = bot
      @bot.on_help(&(method :help))
      @bot.on 'whatsup', &(method :whatsup)
      @bot.on String,    &(method :dm)
    end

    def help(user, data, args, &respond)
      respond.call "Hello, I am Smarty.  I can do the following things:"
      respond.call <<EOM
```
smarty help              Show this message
smarty whatsup           I'll ask you back

If you DM me a question, I can maybe help you find an answer, or
I can ask around for other C5ers to give us some help.  I'll also
catalog the conversation so we can find it again later.

Love, your friend - Dr. Smarty
```
EOM
      true
    end

    def whatsup(user, data, args, &respond)
      respond.call "What's up with you?"
      true
    end

    def dm(user, data, args, &respond)
      return false if data.channel !~ /^D/
      if data.text.downcase == 'help'
        return help user, data, args, &respond
      end
      if user.step == nil
        handle_question user, data, args, &respond
      elsif user.step == :ask
        handle_ask user, data, args, &respond
      end
      user.save
      true
    end

    def handle_question(user, data, args, &respond)
      questions = Question.find data.text
      # respond with links
      # respond "should we ask community"
      user.question = data.text
      user.step = :ask
    end

    def handle_ask(user, data, args, &respond)
      # if yes
      #   post question
      question = Question.new(text: user.question)
      question.save
      # else if no
      #   reset
      # else
      #   reset
      #   goto step 1
      user.step = :anonymous
    end
  end
end
