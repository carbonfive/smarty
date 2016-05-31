module Smarty
  module Config
    def es
      @es ||= ::Elasticsearch::Client.new(url: es_client_url)
    end

    def es_client_url
      ENV['ES_CLIENT_URL']
    end

    def listen_channels
      ENV['LISTEN_CHANNELS'] || []
    end

    def admin_users
      ENV['ADMIN_USERS'] || []
    end
  end
end
