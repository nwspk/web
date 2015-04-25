require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'callbacks' do
    it 'sets the default role on a user on creation' do
      user = Fabricate(:user)
      expect(user.role).to eq User::ROLES[:member]
    end
  end
end
