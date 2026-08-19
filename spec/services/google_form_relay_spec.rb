require 'rails_helper'

RSpec.describe GoogleFormRelay do
  let(:http)         { instance_double(Net::HTTP) }
  let(:confirmation) { GoogleFormRelay::DEFAULT_CONFIRMATION }

  # Net::HTTP.start opens the connection, yields it, and returns the block's
  # value — so the stub hands the double to the block and passes its result on.
  before do
    allow(Net::HTTP).to receive(:start) { |*, &block| block.call(http) }
  end

  def stub_response(code:, body:)
    allow(http).to receive(:post).and_return(double(code: code, body: body))
  end

  describe '.submit' do
    it "is recorded when Google returns the confirmation message" do
      stub_response(code: '200', body: "<html>#{confirmation}</html>")
      expect(described_class.submit('FORMID', { 'entry.1' => 'x' })).to be true
    end

    it "is not recorded when Google re-serves the form (e.g. stale field mapping)" do
      stub_response(code: '200', body: '<html>FB_PUBLIC_LOAD_DATA_ = [...]</html>')
      expect(described_class.submit('FORMID', {})).to be false
    end

    it "is not recorded on a non-200 response" do
      stub_response(code: '302', body: '')
      expect(described_class.submit('FORMID', {})).to be false
    end

    it "is not recorded when the request raises (timeout, DNS, TLS)" do
      allow(http).to receive(:post).and_raise(Net::OpenTimeout)
      expect(described_class.submit('FORMID', {})).to be false
    end

    it "sends Google's housekeeping fields alongside the caller's answers" do
      stub_response(code: '200', body: confirmation)
      described_class.submit('FORMID', { 'entry.1' => 'hello there' })
      expect(http).to have_received(:post) do |_path, body|
        expect(body).to include('fvv=1', 'pageHistory=0', 'entry.1=hello+there')
      end
    end

    it "accepts a form's own confirmation wording" do
      stub_response(code: '200', body: 'Thanks, we got that')
      expect(described_class.submit('FORMID', {})).to be false
      expect(described_class.submit('FORMID', {}, confirmation: 'Thanks, we got that')).to be true
    end
  end

  describe '.date_time_fields' do
    it "splits a datetime-local value into the five parts Google expects" do
      expect(described_class.date_time_fields('entry.9', '2026-08-11T19:30')).to eq(
        'entry.9_year'   => '2026',
        'entry.9_month'  => '8',
        'entry.9_day'    => '11',
        'entry.9_hour'   => '19',
        'entry.9_minute' => '30'
      )
    end

    it "contributes no fields when the optional date was left blank" do
      expect(described_class.date_time_fields('entry.9', '')).to eq({})
    end

    it "contributes no fields for a value it cannot parse" do
      expect(described_class.date_time_fields('entry.9', 'sometime last Tuesday')).to eq({})
    end
  end
end
