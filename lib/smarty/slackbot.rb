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
      else
        puts "Huh?  #{user.step}"
        user.reset
      end
      user.save
      true
    end

    def handle_question(user, data, args, &respond)
      puts "handle_question"
      questions = Question.search data.text
      respond.call "Thanks for your question, #{user.first_name}"
      respond.call "I found some previous topics in Slack that might help out:"
      questions.each { |q| respond.call q.link }
      respond.call "If none of these help, I can ask folks now.  Should I ask now?  (yes or no)"
      user.question = data.text
      user.step = :ask
      true
    end

    def handle_ask(user, data, args, &respond)
      puts "handle_ask"
      t = data.text.downcase
      if [ 'y', 'yes' ].include? t
        wc = @bot.client.web_client
        channel = 'test'
        wc.chat_postMessage channel: channel, text: "Hey everyone, someone has a question..."
        response = wc.chat_postMessage channel: channel, text: "```#{user.question}```"
        ts = response.ts.sub '.', ''
        link = "https://carbonfive.slack.com/archives/#{channel}/p#{ts}"
        question = Question.new text: user.question, link: link
        question.save
        user.step = :anonymous
      elsif [ 'n', 'no' ].include? t
        user.reset
      else
        handle_question user, data, args, &respond
      end

      true
    end
  end
end
