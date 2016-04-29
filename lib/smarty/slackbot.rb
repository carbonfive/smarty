require 'elasticsearch'

module Smarty
  class Slackbot
    def initialize(bot)
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
      respond.call search_results(questions)
      respond.call prompt_to_ask_community
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
        respond.call "Ok, see you later. :kissing_heart:"
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
        someone = "someone"
        emoji = ":bust_in_silhouette:"
        icon = nil
      else
        someone = "<@#{user.slack_id}>"
        emoji = nil
        response = wc.users_info user: user.slack_id
        icon = response.user.profile.image_48
      end

      message = "Hey <!channel>, #{someone} has a question...\n```#{user.question}```"
      response = wc.chat_postMessage channel: channel, text: message, icon_emoji: emoji, icon_url: icon, username: "Dr. Smarty"
      ts = response.ts.sub '.', ''
      link = "https://carbonfive.slack.com/archives/#{channel_name}/p#{ts}"
      question = Question.new text: user.question, link: link
      question.save
      message = "Ok, I asked your question at #{link}. See you next time! :fist:"
      wc.chat_postMessage channel: user.slack_im_id, text: message, icon_emoji: ":nerd_face:", username: "Dr. Smarty"
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

    private

    def search_results(questions)
      if questions.empty?
        "I don't think that question has been asked before."
      else
        questions_links = @questions.map(&:link).join('\n')
        "I found some previous topics in Slack that might help out:\n#{questions_links}"
      end
    end

    def prompt_to_ask_community
      "If isn't helpful, I can ask folks now.  Should I ask now?  (yes or no)"
    end
  end
end
