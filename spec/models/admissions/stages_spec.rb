require 'rails_helper'

# The rules written out by hand from SPEC §3, so a change to the stage
# machine's tables has to be made here too, deliberately.
RSpec.describe Admissions::Stages do
  it 'has the twelve funnel stages in order' do
    expect(described_class::FUNNEL).to eq %w[
      eoi invited applied task_sent task_returned interview_offered
      interview_booked interviewed offered accepted contracts_sent confirmed
    ]
  end

  it 'has on_hold and the four exits' do
    expect(described_class::ON_HOLD).to eq 'on_hold'
    expect(described_class::EXITS).to eq %w[deferred declined rejected withdrawn]
    expect(described_class::TERMINAL).to match_array %w[confirmed deferred declined rejected withdrawn]
  end

  it 'allows exactly these transitions, by exactly these actors' do
    expect(described_class::TRANSITIONS).to eq(
      %w[eoi invited] => %w[staff system],
      %w[invited applied] => %w[applicant staff],
      %w[applied task_sent] => %w[staff],
      %w[task_sent task_returned] => %w[applicant staff],
      %w[task_returned interview_offered] => %w[staff],
      %w[interview_offered interview_booked] => %w[applicant staff],
      %w[interview_booked interview_offered] => %w[applicant staff],
      %w[interview_booked interviewed] => %w[staff],
      %w[interviewed offered] => %w[staff],
      %w[offered accepted] => %w[applicant staff],
      %w[accepted contracts_sent] => %w[staff],
      %w[contracts_sent confirmed] => %w[staff]
    )
  end

  it 'lets exits be reached by these actors' do
    expect(described_class::EXIT_ACTORS).to eq(
      'deferred' => %w[applicant staff system], 'declined' => %w[applicant staff],
      'rejected' => %w[staff], 'withdrawn' => %w[applicant staff]
    )
  end

  it 'reaches the exits from every non-exit, and withdrawal from the other exits too' do
    non_exits = described_class::FUNNEL + ['on_hold']
    %w[deferred declined rejected].each do |to|
      expect(non_exits).to all(satisfy { |from| described_class.exit_reachable?(from, to) })
      expect(described_class::EXITS.none? { |from| described_class.exit_reachable?(from, to) }).to be true
    end
    expect((non_exits + %w[deferred declined rejected]).all? { |f| described_class.exit_reachable?(f, 'withdrawn') }).to be true
    expect(described_class.exit_reachable?('withdrawn', 'withdrawn')).to be false
    expect(described_class.exit_reachable?('eoi', 'confirmed')).to be false
  end

  it 'holds from every non-terminal funnel stage only' do
    expect(described_class::FUNNEL.select { |s| described_class.holdable?(s) }).to eq described_class::FUNNEL - ['confirmed']
    expect((described_class::EXITS + %w[on_hold confirmed]).none? { |s| described_class.holdable?(s) }).to be true
  end

  it 'has the waiting-on party SPEC §3 gives each non-terminal stage' do
    expect(described_class::WAITING_ON.select { |_, who| who == :applicant }.keys)
      .to eq %w[invited task_sent interview_offered offered contracts_sent]
    expect(described_class::WAITING_ON.select { |_, who| who == :staff }.keys)
      .to eq %w[applied task_returned interviewed accepted]
    expect(described_class::WAITING_ON.keys).to eq described_class::FUNNEL - ['confirmed']
  end
end
