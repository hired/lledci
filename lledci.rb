require 'limitless_led'
require 'json'
require 'crack'

class LimitlessLedCi < Sinatra::Application

  NEWRELIC_API_KEY = '311a19178c2d6782788545bf3e1b584e5eeca999de19cdc'
  NEWRELIC_ACCOUNT_ID = 252235
  NEWRELIC_APP_ID = 1350161

  set :protection, origin_whitelist: ['chrome-extension://hgmloofddffdnphfgcellkdfbfbjeloo']

  get '/' do
    "Limitless LED CI"
  end

  post '/tddium' do
    params = JSON.parse(request.body.read)
    return unless params['branch'] == 'master' && params['event'] == 'stop'

    bridge = LimitlessLed::Bridge.new(host: '172.16.0.7')
    light = bridge.group(1)
    case params['status']
      when 'error'
        light.color 'Yellow'
      when 'passed'
        light.color 'Green'
      when 'failed'
        light.color 'Red'
      else
        raise "Unknown build status: #{params['status']}"
    end

    "Build #{params['status']}!"
  end

  helpers do
    def get_newrelic_apdex
      response = Curl::Easy.perform("https://api.newrelic.com/api/v1/accounts/#{NEWRELIC_ACCOUNT_ID}/applications/#{NEWRELIC_APP_ID}/threshold_values.json") do |curl|
        curl.headers["x-api-key"] = NEWRELIC_API_KEY
      end

      parsed = Crack::XML.parse(response.body_str)
      parsed['threshold_values'].detect{|obj| obj['name'] == 'Apdex'}['metric_value'].to_f
    end

    def apdex_to_color_code(apdex)
      working_value = apdex - 0.5
      return 170 if working_value <= 0
      (170 - working_value**2 * 85 * 4).to_i
    end
  end

  Thread.abort_on_exception = true
  Thread.new do
    bridge = LimitlessLed::Bridge.new(host: '172.16.0.7')
    while true do
      puts 'checking now'
      helpers = self.new.helpers
      apdex = helpers.get_newrelic_apdex
      puts apdex: apdex
      light = bridge.group(2)
      light.brightness  10
      sleep 0.15
      light.color       helpers.apdex_to_color_code(apdex)
      sleep 0.1
      light.brightness  27
      sleep 120
    end
  end

end


