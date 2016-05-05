require 'elasticsearch'

module Smarty
  class Slackbot

    AVATAR_ICON_URL = "http://sdurham.net/smarty/dm/bot0.jpg"

    def initialize(bot)
      bot.config.extend Config
      Question.config = bot.config
      Slacky::User.decorator = User
      Slacky::Message.decorator = Message

      init_elasticsearch

      listen_channels = Slacky::Channel.find [ '#test', '#general', '#development', '#design', '#product_management' ]

      @bot = bot
      @bot.on_command 'whatsup', &(method :whatsup)
      @bot.on_command 'help',    &(method :help)
      @bot.on_im nil, &(method :dm)
      @bot.on_message({ channels: listen_channels }, &(method :question_detector))

      @bot.on 'channel_joined', &(method :joined)
    end

    def init_elasticsearch
      # Reset for Demo
      Question.delete_index
      Question.create_index
      Question.seed
    end

    def question_detector(message)
      return if message.raw.subtype == 'bot_message'

      wc = @bot.web_client
      if message.question?
        im = wc.im_open user: message.user.slack_id
        channel_name = message.channel.name
        msg = "Hi, it looks like you just asked a question in ##{channel_name}:\n```#{message.text}```\nI can remember your question and any related conversation for later use.  Should I do that?"
        wc.chat_postMessage channel: im.channel.id, text: msg, as_user: false, icon_url: AVATAR_ICON_URL, username: "Dr. Smarty"
        ts = message.raw.ts.sub '.', ''
        link = "https://carbonfive.slack.com/archives/#{channel_name}/p#{ts}"
        message.user.question = message.text
        message.user.link = link
        message.user.step = :detect
        message.user.save
      end
    end

    def help(message)
      message.reply "Hello, I am Smarty.  I can do the following things:"
      message.reply <<EOM
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

    def whatsup(message)
      help message
    end

    def dm(message)
      case message.user.step
      when nil        ; handle_question message
      when :anonymous ; handle_anonymous message
      when :channel   ; handle_channel message
      when :ask       ; handle_ask message
      when :detect    ; handle_detect message
      else
        puts "Huh? #{message.user.step}"
        message.user.reset
      end
      message.user.save
    end

    def handle_question(message)
      puts "handle_question"
      questions = Question.search message.text
      if questions.empty?
        message.reply "Interesting question, I haven't heard it before.  Should I bring it to the group?"
      else
        links = questions.map(&:link)
        message.reply "Oh, I've heard people talking about this before.  Maybe these will help:\n"
        links.each { |link| message.reply "#{link}##{(Time.now.to_f * 10000).truncate}" }
        message.reply "If these aren't helpful, we can bring it to the group.  Should I do that now?"
      end
      message.user.question = message.text
      message.user.step = :anonymous
    end

    def handle_anonymous(message)
      puts "handle_anonymous"
      if message.yes?
        message.reply "Ok I'll ask the group in a sec.  Should I post this question anonymously?"
        message.user.step = :channel
      elsif message.no?
        message.reply "Ok, see you later. :kissing_heart:"
        message.user.reset
      else
        handle_question message
      end
    end

    def handle_channel(message)
      puts "handle_channel"
      if message.yes?
        message.user.anonymous = true
      elsif message.no?
        message.user.anonymous = false
      else
        return handle_question message
      end

      message.reply "Got it.  What channel should I post it to?  (#general, #development, #design, etc)"
      message.user.step = :ask
    end

    def handle_ask(message)
      puts "handle_ask"
      if matches = message.text.match(/^<#(\w+)>$/)
        channel = Slacky::Channel.find matches.captures[0]
        if channel.member?
          ask message.user, channel
          message.user.reset
        else
          message.user.channel = channel.name
          message.reply "I don't seem to have access to that channel.  If you go invite me now I'll post your question.  Or you can choose a new channel."
        end
      elsif message.text =~ /^#\w+$/
        message.reply "That channel does not exist.  Did you misspell it?  Try again. I'll wait... :thinking_face:"
      else
        handle_question message
      end
    end

    def ask(user, channel)
      wc = @bot.web_client
      if user.anonymous?
        someone = "anonymous user"
        big_icon = random_anonymous_icon
        icon = nil
      else
        someone = user.username
        response = wc.users_info user: user.slack_id
        big_icon = AVATAR_ICON_URL
        icon = response.user.profile.image_48
      end

      message = "Hey <!channel>, someone has a question..."
      attachments = {
        'fallback': message,
        'author_name': someone,
        'author_icon': icon,
        'color': '#51bf92',
        'pretext': message,
        'text': user.question
      }

      response = wc.chat_postMessage channel: channel.slack_id, as_user: false, attachments: [attachments], icon_url: big_icon, username: "Dr. Smarty"
      ts = response.ts.sub '.', ''
      link = "https://carbonfive.slack.com/archives/#{channel.name}/p#{ts}"
      question = Question.new text: user.question, link: link
      question.save
      message = "Ok, I asked your question at #{link}. See you next time! :fist:"
      wc.chat_postMessage channel: user.slack_im_id, as_user: false, text: message, icon_url: AVATAR_ICON_URL, username: "Dr. Smarty"
      user.reset
    end

    def handle_detect(message)
      puts "handle_detect"
      if message.yes?
        message.reply "Excellent!  Consider it done.  FYI, you can learn more about me just by typing `help`."
        Question.new(text: message.user.question, link: message.user.link).save
      elsif message.no?
        message.reply "Ok, no problemo.  I'll leave this one alone.  FYI, you can learn more about me by typing `help`."
      else
        message.reply "Err... I didn't understand that.  Tell you what, I'm not gonna do anything right now.  But you can learn more about me by typing `help`.  See you soon!  :kissing_heart:"
      end
      message.user.reset
    end

    def joined(data)
      channel = Channel.find data.channel.id
      response = @bot.web_client.channels_history channel: channel.slack_id, count: 3
      invitation = response.messages.find { |m| m.subtype == 'channel_join' && m.inviter? }
      return unless invitation
      user = Slacky::User.find invitation.inviter
      return unless user.channel == channel.name
      ask user, channel
      user.save
    end

    def random_anonymous_icon
      "http://sdurham.net/smarty/anonymous/bot#{rand(0..9)}.jpg"
    end
  end
end
