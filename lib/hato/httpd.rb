require 'json'
require 'sinatra'
require 'sinatra/logger'

module Hato
  class Httpd
    def initialize(observer, config)
      @observer = observer
      @config   = config
    end

    def run
      App.set(:observer, @observer)
      App.set(:api_key,  @config.api_key)

      Rack::Handler::WEBrick.run(
        App.new,
        Host: @config.host || '0.0.0.0',
        Port: @config.port || 9699,
      )
    end

    class App < Sinatra::Base
      enable :logging

      before /\/.+/ do
        if settings.api_key && (settings.api_key != params[:api_key])
          halt 403, JSON.dump(
            status:  :error,
            message: 'API key is wrong. Confirm your API key setting of server/client.',
          )
        end
      end

      get '/' do
        'Hato https://github.com/kentaro/hato'
      end

      post '/notify' do
        settings.observer.update(
          tag:     params[:tag],
          message: params[:message],
          logger:  logger,
        )

        JSON.dump(
          status:  :success,
          message: 'Successfully sent the message you notified to me.',
        )
      end

      post '/webhook/:owner/:repository' do
        event = request.env['X-GitHub-Event']

        if !event
          halt 400, JSON.dump(
            status:  :error,
            message: 'Missing mandatory header: `X-GitHub-Event`',
          )
        end

        tag     = ['webhook', params[:owner], params[:repository]].join('.')
        payload = params[:payload]

        if !payload
          halt 400, JSON.dump(
            status:  :error,
            message: 'Missing mandatory parameter: `payload`',
          )
        end

        settings.observer.update(
          tag:     tag,
          event:   event,
          payload: payload,
          logger:  logger,
        )

        JSON.dump(
          status:  :success,
          message: 'Successfully sent the message you notified to me.',
        )
      end
    end
  end
end
