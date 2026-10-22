require 'rails_helper'

RSpec.describe Admissions::FormText do
  let(:lead) { admissions_staff }

  def write(key, body) = described_class.create!(key: key, body: body, created_by_user: lead)

  it 'reads the latest version of each key' do
    write('privacy_notice', 'First test notice.')
    write('eoi_introduction', 'Test intro.')
    latest = write('privacy_notice', 'Second test notice.')

    expect(described_class.current('privacy_notice')).to eq latest
    expect(described_class.text('privacy_notice')).to eq 'Second test notice.'
    expect(described_class.history('privacy_notice').map(&:body)).to eq ['Second test notice.', 'First test notice.']
  end

  it 'has no text for a key never written, or written blank' do
    expect(described_class.text('eoi_introduction')).to be_nil
    write('eoi_introduction', '')
    expect(described_class.text('eoi_introduction')).to be_nil
  end

  it 'knows only its keys' do
    expect { described_class.current('other') }.to raise_error(ArgumentError)
    expect(described_class.new(key: 'other', body: 'x', created_by_user: lead)).not_to be_valid
  end

  it 'needs someone to attribute it to' do
    expect(described_class.new(key: 'eoi_introduction', body: 'x')).not_to be_valid
  end

  it 'never changes a saved version, in Ruby or in the database' do
    version = write('privacy_notice', 'Test notice.')

    expect { version.update!(body: 'Changed') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect_refused(ActiveRecord::StatementInvalid, /append-only/) { described_class.where(id: version.id).update_all(body: 'x') }
    expect_refused(ActiveRecord::StatementInvalid, /append-only/) { described_class.where(id: version.id).delete_all }
    expect_refused(ActiveRecord::StatementInvalid, /append-only/) do
      described_class.connection.execute('TRUNCATE admissions_form_texts CASCADE')
    end
    expect(version.reload.body).to eq 'Test notice.'
  end

  it 'keeps a lead who wrote one from being deleted, so the version keeps naming them' do
    write('eoi_introduction', 'Test intro.')
    expect(lead.destroy).to be false
    expect(lead.errors[:base]).to include('has acted as admissions staff; remove their admissions role instead')
  end
end
