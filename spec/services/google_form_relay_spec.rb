require 'rails_helper'

RSpec.describe GoogleFormRelay do
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  def stub_response(code:, body:)
    allow(http).to receive(:post).and_return(double(code: code, body: body))
  end

  it "is recorded when Google returns the confirmation message" do
    stub_response(code: '200', body: '<html>Your response has been recorded</html>')
    expect(described_class.submit('FORMID', { 'entry.1' => 'x' }, confirmation: 'Your response has been recorded')).to be true
  end

  it "is not recorded when Google re-serves the form (e.g. stale field mapping)" do
    stub_response(code: '200', body: '<html>FB_PUBLIC_LOAD_DATA_ = [...]</html>')
    expect(described_class.submit('FORMID', {}, confirmation: 'Your response has been recorded')).to be false
  end

  it "is not recorded on a non-200 response" do
    stub_response(code: '302', body: '')
    expect(described_class.submit('FORMID', {}, confirmation: 'Your response has been recorded')).to be false
  end

  it "is not recorded when the request raises (timeout, DNS, TLS)" do
    allow(http).to receive(:post).and_raise(Net::OpenTimeout)
    expect(described_class.submit('FORMID', {}, confirmation: 'Your response has been recorded')).to be false
  end
end
