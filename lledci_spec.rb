require 'bundler'
Bundler.require

require './lledci'
require 'rspec'
require 'rack/test'
require 'webmock/rspec'

describe 'Limitless LED CI' do
  include Rack::Test::Methods

  def app
    LimitlessLedCi
  end

  it 'says hi' do
    get '/'
    last_response.body.should == 'Limitless LED CI'
  end

  describe '/tddium' do
    def payload(status: 'passed', branch: 'master', event: 'stop')
       {
        "event" => event,
        "session" => 351279,
        "commit_id" => "38d4d2548e85729e138fdba32e08421bb899ba37",
        "status" => status,
        "counts" => {
          "notstarted" => 0,
          "started" => 0,
          "passed" => 234.0,
          "failed" => 0.0,
          "pending" => 3.0,
          "skipped" => 0.0,
          "error" => 0.0
        },
        "workers" => 24,
        "branch" => branch,
        "ref" => "refs/head/production",
        "repository" => {"name" => "repo_name", "url" => "ssh://git@github.com/organization_name/repo_name", "org_name" => "organization_name"},
        "xid" => "372da4f69"
       }.to_json
    end

    def webhook(options)
      post '/tddium', payload(options), { "CONTENT_TYPE" => "application/json" }
    end

    let(:mock_light) { mock(:mock_light, color: true, brightness: true)}
    let(:mock_bridge) { mock(:mock_bridge, group: mock_light ) }

    context 'when branch is master and event is "stop"' do
      before do
        LimitlessLed::Bridge.should_receive(:new) { mock_bridge }
      end

      it 'changes the LED color to green when the build passes' do
        mock_light.should_receive(:color).with('Green')
        webhook(status: 'passed')
        pp last_response.body
        last_response.status.should == 200
        last_response.body.should == 'Build passed!'
      end

      it 'changes the LED color to red when the build fails' do
        mock_light.should_receive(:color).with('Red')

        webhook(status: 'failed')
        last_response.status.should == 200
        last_response.body.should == 'Build failed!'
      end

      it 'changes the LED color to yellow when the build errors' do
        mock_light.should_receive(:color).with('Yellow')

        webhook(status: 'error')
        last_response.status.should == 200
        last_response.body.should == 'Build error!'
      end

      it 'raises an exception when the payload is unknown' do
        webhook(status: 'hippopotamus')
        last_response.status.should == 500
        last_response.body.should include('Unknown build status: hippopotamus ')
      end
    end

    context 'when the branch and event do not match our criteria' do
      before do
        LimitlessLed::Bridge.should_not_receive(:new)
      end

      it 'does nothing unless the branch is master' do
        webhook(branch: 'other')
        last_response.status.should == 200
      end

      it 'does nothing unless the event is stop' do
        webhook(event: 'start')
        last_response.status.should == 200
      end

    end
  end

  describe '#get_newrelic_apdex' do
    it 'makes a request to NewRelic using the NewRelic API' do
      stub = stub_request(:get, "https://api.newrelic.com/api/v1/accounts/#{LimitlessLedCi::NEWRELIC_ACCOUNT_ID}/applications/#{LimitlessLedCi::NEWRELIC_APP_ID}/threshold_values.json")
        .to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<threshold-values type=\"array\">\n  <threshold_value name=\"Apdex\" metric_value=\"0.86\" threshold_value=\"2\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"0.86 [0.5]\"/>\n  <threshold_value name=\"Application Busy\" metric_value=\"7.2\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"7.2%\"/>\n  <threshold_value name=\"Error Rate\" metric_value=\"0.151\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"0.151%\"/>\n  <threshold_value name=\"Throughput\" metric_value=\"136\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"136 rpm\"/>\n  <threshold_value name=\"Errors\" metric_value=\"0.667\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"0.667 epm\"/>\n  <threshold_value name=\"Response Time\" metric_value=\"500\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"500 ms\"/>\n  <threshold_value name=\"DB\" metric_value=\"27.1\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"27.1%\"/>\n  <threshold_value name=\"CPU\" metric_value=\"55.1\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"55.1%\"/>\n  <threshold_value name=\"Memory\" metric_value=\"3400\" threshold_value=\"1\" begin_time=\"2014-01-27 18:51:23\" end_time=\"2014-01-27 18:54:23\" formatted_metric_value=\"3,400 MB\"/>\n</threshold-values>\n")

      app.new.helpers.get_newrelic_apdex.should == 0.86
      stub.should have_been_requested
    end
  end

  describe '#apdex_to_color_code' do

    it 'returns full Green for 1.0' do
      app.new.helpers.apdex_to_color_code(1.0).should == 85
    end

    it 'returns mostly green for 0.95' do
      app.new.helpers.apdex_to_color_code(0.95).should == 101
    end

    it 'returns mostly green for 0.85' do
      app.new.helpers.apdex_to_color_code(0.85).should == 128
    end

    it 'returns mostly green for 0.75' do
      app.new.helpers.apdex_to_color_code(0.75).should == 148
    end

    it 'returns mostly green for 0.6' do
      app.new.helpers.apdex_to_color_code(0.6).should == 166
    end

    it 'returns full Red for any value less than 0.5' do
      app.new.helpers.apdex_to_color_code(0.5).should == 170
      app.new.helpers.apdex_to_color_code(0.49).should == 170
      app.new.helpers.apdex_to_color_code(0.1).should == 170
    end
  end

  describe '#update_apdex_indicator' do


  end

end