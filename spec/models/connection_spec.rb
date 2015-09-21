require 'rails_helper'

RSpec.describe Connection, type: :model do
  describe '#expired?' do
    let(:connection) { Connection.new }

    it 'returns false if the token is fresh' do
      connection.expires_at = Time.now + 500
      expect(connection.expired?).to be false
    end

    it 'returns false if the token will never expire' do
      connection.expires_at = nil
      expect(connection.expired?).to be false
    end

    it 'returns true if the token expired' do
      connection.expires_at = Time.now - 500
      expect(connection.expired?).to be true
    end
  end
end
