require 'rails_helper'

RSpec.describe Admissions::CardByHand do
  let(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:officer) { admissions_staff(role: 'officer') }
  let(:actor) { Admissions::Actor.staff(officer) }

  def card(**attrs)
    described_class.new(round_id: round.id, email: 'new@example.com', name: 'New Person', stage: 'eoi', **attrs)
  end

  it 'offers the confirmation and the holding email at eoi, and nothing at any other stage' do
    expect(card.offered_emails).to eq %w[confirmation holding]
    (Admissions::Stages::FUNNEL - ['eoi']).each do |stage|
      expect(card(stage: stage).offered_emails).to eq([]), stage
    end
  end

  it 'creates nothing when an email ticked can no longer be drafted' do
    template = email_template(round, 'confirmation')
    form = card(send_emails: ['confirmation'])
    expect(form.previews.map(&:sendable?)).to eq [true, false]
    template.destroy!

    expect(form.save(actor)).to be false
    expect(form.errors[:base].first).to start_with('Nothing was created: There is no EOI confirmation template')
    expect(Admissions::Applicant.count).to eq 0
    expect(recorded_emails).to be_empty
  end

  it 'sends only after the card has committed, and records who approved it' do
    email_template(round, 'confirmation')
    form = card(send_emails: ['confirmation'])
    expect(form.save(actor)).to be true
    expect(form.emails.map { |e| [e.status, e.sent_by_user, e.delivery] }).to eq [['sent', officer, 'recording']]
    expect(form.applicant.events.reorder(:id).pluck(:kind))
      .to eq %w[created email_drafted email_sending email_sent]
  end

  it 'refuses the same address in the same round, naming the existing card, even when a race wins first' do
    existing = create_applicant(round: round, email: 'NEW@example.com')
    form = card
    expect(form.valid?).to be false
    expect(form.existing).to eq existing

    # The check passed before the other card was created: the unique index refuses this one.
    racing = card(email: 'race@example.com')
    expect(racing.valid?).to be true
    other = create_applicant(round: round, email: 'race@example.com')
    allow(racing).to receive(:valid?).and_return(true)
    expect(racing.save(actor)).to be false
    expect(racing.existing).to eq other
    expect(racing.errors[:email]).to include('Fellowship 2027 already has a card for this address.')
    expect(round.applicants.where('lower(email) = ?', 'race@example.com').count).to eq 1
  end

  it 'accepts no date that is unreadable or in the future' do
    expect(card(first_interest_on: 'last spring').tap(&:valid?).errors[:first_interest_on]).to eq ["That isn't a date."]
    expect(card(first_interest_on: Date.current + 1).tap(&:valid?).errors[:first_interest_on])
      .to eq ["That's in the future."]
    expect(card(first_interest_on: Date.current).valid?).to be true
    expect(card(first_interest_on: '').valid?).to be true
  end
end
