require 'limitless_led'
require 'json'

class LimitlessLedCi < Sinatra::Application

  set :protection, origin_whitelist: ['chrome-extension://hgmloofddffdnphfgcellkdfbfbjeloo']

  get '/' do
    "Limitless LED CI"
  end

  post '/tddium' do
    request.body.rewind  # in case someone already read it
    data = JSON.parse request.body.read
    puts data.inspect
    return unless data['branch'] == 'master' && data['event'] == 'stop'
    bridge = LimitlessLed::Bridge.new(host: 'lled.hired.local')

    case data['status']
      when 'passed'
        bridge.color 85
      when 'failed'
        bridge.color 170
      else
        raise "Unknown build status: #{data['status']}"
    end

    "Build #{data['status']}!"
  end

end

