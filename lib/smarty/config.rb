module Smarty
  module Config
    def es
      @es ||= ::Elasticsearch::Client.new(url: es_client_url)
    end

    def es_client_url
      @config[:es_client_url]
    end
  end
end
