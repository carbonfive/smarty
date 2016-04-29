require 'elasticsearch'

module Smarty
  class Slackbot

    GENERAL_ICON_URL = "http://sdurham.net/smarty/general/bot0.png"
    DM_ICON_URL = "http://sdurham.net/smarty/dm/bot0.png"

    def initialize(bot)
      channels = [ 'test', 'general', 'development', 'design', 'product_management' ]
      resp = bot.client.web_client.channels_list
      @good_channels = Hash[resp.channels.select {|c| channels.include? c.name}.map {|c| [ c.id, c.name ]}]

      Slacky::User.decorator = User

      @config = bot.config
      @config.extend Config

      init_elasticsearch

      Question.config = @config

      @bot = bot
      @bot.on_help(&(method :help))
      @bot.on 'whatsup', &(method :whatsup)
      @bot.on String,    &(method :dm)

      @bot.client.on 'channel_joined', &(method :joined)
      @bot.client.on 'message', &(method :question_detector)
    end

    def init_elasticsearch
      puts "Using ES: #{@config.es_client_url}"
      es = @config.es
      unless es.indices.exists? index: Question::INDEX
        es.indices.create index: Question::INDEX,
          body: {
            mappings: {
              document: {
                properties: {
                  text: { type: 'string', index: 'analyzed' },
                  link: { type: 'string', index: 'not_analyzed' }
                }
              }
            }
          }
      end
    end

    def question_detector(data)
      return unless @good_channels[data.channel]
      return if data.user == @bot.slack_id
      return if data.subtype == 'bot_message'

      wc = @bot.client.web_client
      if data.text.split(' ').length >= 5 && data.text =~ /\?$/
        p data
        user = Slacky::User.find data.user
        im = wc.im_open user: user.slack_id
        channel = @good_channels[data.channel]
        message = "Hi, it looks like you just asked a question in ##{channel}:\n```#{data.text}```\nI can remember your question and any related conversation for later use.  Should I do that?"
        wc.chat_postMessage channel: im.channel.id, text: message, as_user: false, icon_url: GENERAL_ICON_URL, username: "Dr. Smarty"
        ts = data.ts.sub '.', ''
        link = "https://carbonfive.slack.com/archives/#{channel}/p#{ts}"
        user.question = data.text
        user.link = link
        user.step = :detect
        user.save
      end
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
      help user, data, args, &respond
    end

    def dm(user, data, args, &respond)
      return false if data.channel !~ /^D/
      user.slack_im_id = data.channel
      return if [ 'help', 'whatsup' ].include? data.text.downcase
      if user.step == nil
        handle_question user, data, args, &respond
      elsif user.step == :anonymous
        handle_anonymous user, data, args, &respond
      elsif user.step == :channel
        handle_channel user, data, args, &respond
      elsif user.step == :ask
        handle_ask user, data, args, &respond
      elsif user.step == :detect
        handle_detect user, data, args, &respond
      else
        puts "Huh?  #{user.step}"
        user.reset
      end
      user.save
      true
    end

    def yes?(text)
      [ 'y', 'yes' ].include? text.downcase
    end

    def no?(text)
      [ 'n', 'no' ].include? text.downcase
    end

    def handle_question(user, data, args, &respond)
      puts "handle_question"
      questions = Question.search data.text
      if questions.empty?
        respond.call "Interesting question, I haven't heard it before.  Should I bring it to the group?"
      else
        questions_links = questions.map(&:link).join('\n')
        respond.call "Oh, I've heard people talking about this before.  Maybe these will help:\n#{questions_links}"
        respond.call "If these aren't helpful, we can bring it to the group.  Should I do that now?"
      end
      user.question = data.text
      user.step = :anonymous
      true
    end

    def handle_anonymous(user, data, args, &respond)
      puts "handle_anonymous"
      if yes? data.text
        respond.call "Ok I'll ask the group in a sec.  Should I post this question anonymously?"
        user.step = :channel
      elsif no? data.text
        respond.call "Ok, see you later. :kissing_heart:"
        user.reset
      else
        handle_question user, data, args, &respond
      end
      true
    end

    def handle_channel(user, data, args, &respond)
      puts "handle_channel"
      if yes? data.text
        user.anonymous = true
      elsif no? data.text
        user.anonymous = false
      else
        return handle_question user, data, args, &respond
      end

      respond.call "Got it.  What channel should I post it to?  (#general, #development, #design, etc)"
      user.step = :ask
      true
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
          user.channel = channel_name
          respond.call "I don't seem to have access to that channel.  If you go invite me now I'll post your question.  Or you can choose a new channel."
          return
        end
      elsif data.text =~ /^#\w+$/
        respond.call "That channel does not exist.  Did you misspell it?  Try again. I'll wait... :thinking_face:"
        return
      else
        return handle_question user, data, args, &respond
      end

      ask user, channel, channel_name
      user.reset
    end

    def ask(user, channel, channel_name)
      wc = @bot.client.web_client
      if user.anonymous?
        someone = "anonymous user"
        icon = random_anonymous_icon
      else
        someone = user.username
        response = wc.users_info user: user.slack_id
        icon = response.user.profile.image_48
      end

      message = "Hey <!channel>, someone has a question..."
      attachments =
          {
              'fallback': message,
              'author_name': someone,
              'author_icon': icon,
              'color': '#51bf92',
              'pretext': message,
              'text': user.question
          }

      response = wc.chat_postMessage channel: channel, as_user: false, attachments: [attachments], icon_url: GENERAL_ICON_URL, username: "Dr. Smarty"
      ts = response.ts.sub '.', ''
      link = "https://carbonfive.slack.com/archives/#{channel_name}/p#{ts}"
      question = Question.new text: user.question, link: link
      question.save
      message = "Ok, I asked your question at #{link}. See you next time! :fist:"
      wc.chat_postMessage channel: user.slack_im_id, as_user: false, text: message, icon_url: DM_ICON_URL, username: "Dr. Smarty"
      user.reset
    end

    def handle_detect(user, data, args, &respond)
      puts "handle_detect"
      if yes? data.text
        respond.call "Excellent!  Consider it done.  FYI, you can learn more about me just by typing `help`."
        Question.new(text: user.question, link: user.link).save
      elsif no? data.text
        respond.call "Ok, no problemo.  I'll leave this one alone.  FYI, you can learn more about me by typing `help`."
      else
        respond.call "Err... I didn't understand that.  Tell you want, I'm not gonna do anything right now.  But you can learn more about me by typing `help`.  See you soon!  :kissing_heart:"
      end
      user.reset
    end

    def joined(data)
      channel = data.channel.id
      response = @bot.client.web_client.channels_history channel: channel, count: 3
      invitation = response.messages.find { |m| m.subtype == 'channel_join' && m.inviter? }
      return unless invitation
      user = Slacky::User.find invitation.inviter
      channel_name = data.channel.name
      return unless user.channel == channel_name
      ask user, channel, channel_name
      user.save
    end

    def random_anonymous_icon
      url = "http://sdurham.net/smarty/anonymous/bot#{rand(0..9)}.png"
    end

  end
end
