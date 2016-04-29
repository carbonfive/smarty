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
      elsif user.step == :anonymous
        handle_anonymous user, data, args, &respond
      elsif user.step == :channel
        handle_channel user, data, args, &respond
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
      user.step = :anonymous
      true
    end

    def handle_anonymous(user, data, args, &respond)
      puts "handle_anonymous"
      t = data.text.downcase
      if [ 'y', 'yes' ].include? t
        respond.call "Great, I'll go ahead and ask.  Should I post this question anonymously?  (yes or no)"
        user.step = :channel
      elsif [ 'n', 'no' ].include? t
        respond.call "Ok, see you later"
        user.reset
      else
        handle_question user, data, args, &respond
      end
      true
    end

    def handle_channel(user, data, args, &respond)
      puts "handle_channel"
      t = data.text.downcase
      if [ 'y', 'yes' ].include? t
        user.anonymous = true
      elsif [ 'n', 'no' ].include? t
        user.anonymous = false
      else
        return handle_question user, data, args, &respond
      end

      respond.call "Got it.  So then what channel should I post it to?  (#general, #development, #design, etc)"
      user.step = :ask
    end

    def handle_ask(user, data, args, &respond)
      puts "handle_ask"

      channel = nil
      channel_name = nil
      wc = @bot.client.web_client
      if matches = data.text.match(/^<#(\w+)>$/)
        channel = matches.captures[0]
        response = wc.channels_info channel: channel
        channel_name = response.channel.name
        unless response.channel.members.include? @bot.slack_id
          respond.call "I don't seem to have access to that channel.  Before I can post messages you need to invite me to join the channel.\n" +
                       "Sorry, but you have to start over by asking your question again.  :open_mouth:"
          user.reset
          return true
        end
      elsif data.text =~ /^#\w+$/
        respond.call "That channel does not exist.  Did you misspell it?\n" +
                     "Sorry, but you have to start over by asking your question again.  :open_mouth:"
        user.reset
        return true
      else
        return handle_question user, data, args, &respond
      end

      if user.anonymous?
        someone = "someone"
        emoji = ":bust_in_silhouette:"
        icon = nil
      else
        someone = "@#{user.username}"
        emoji = nil
        response = wc.users_info user: user.slack_id
        icon = response.user.profile.image_48
      end

      message = "Hey everyone, #{someone} has a question...\n```#{user.question}```"
      response = wc.chat_postMessage channel: channel, text: message, icon_emoji: emoji, icon_url: icon, username: "Dr. Smarty"
      ts = response.ts.sub '.', ''
      link = "https://carbonfive.slack.com/archives/#{channel_name}/p#{ts}"
      question = Question.new text: user.question, link: link
      question.save
      respond.call "Ok, I asked your question at #{link}"
      user.reset
      true
    end

  end
end
