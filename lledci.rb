require 'limitless_led'
require 'json'

class LimitlessLedCi < Sinatra::Application

  set :protection, origin_whitelist: ['chrome-extension://hgmloofddffdnphfgcellkdfbfbjeloo']

  get '/' do
    "Limitless LED CI"
  end

  post '/tddium' do
    params = JSON.parse(request.body.read)
    return unless params['branch'] == 'master' && params['event'] == 'stop'
    bridge = LimitlessLed::Bridge.new(host: '172.16.0.7')

    case params['status']
      when 'error'
        bridge.color 'Yellow'
      when 'passed'
        bridge.color 85
      when 'failed'
        bridge.color 170
      else
        raise "Unknown build status: #{params['status']}"
    end

    "Build #{params['status']}!"
  end

end

