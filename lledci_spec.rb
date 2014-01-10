require 'bundler'
Bundler.require

require './lledci'
require 'rspec'
require 'rack/test'

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

    let(:mock_bridge) { mock(:mock_bridge, :color => true ) }

    context 'when branch is master and event is "stop"' do
      before do
        LimitlessLed::Bridge.should_receive(:new) { mock_bridge }
      end

      it 'changes the LED color to green when the build passes' do
        mock_bridge.should_receive(:color).with(85)
        webhook(status: 'passed')
        last_response.status.should == 200
        last_response.body.should == 'Build passed!'
      end

      it 'changes the LED color to red when the build fails' do
        mock_bridge.should_receive(:color).with(170)

        webhook(status: 'failed')
        last_response.status.should == 200
        last_response.body.should == 'Build failed!'
      end

      it 'changes the LED color to yellow when the build errors' do
        mock_bridge.should_receive(:color).with('Yellow')

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

end