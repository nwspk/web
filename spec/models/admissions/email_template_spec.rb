require 'rails_helper'

RSpec.describe Admissions::EmailTemplate do
  let(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let(:applicant) { create_applicant(round: round, name: 'Test Person') }

  def template(**attrs)
    described_class.new(round: round, email_type: 'confirmation', subject: 'S', body: 'B', **attrs)
  end

  it 'fills the placeholders from the applicant' do
    rendered = template(subject: 'Hello {{ name }}', body: '{{name}} applied to {{round}}.').render(applicant)
    expect(rendered.to_h).to eq(subject: 'Hello Test Person', body: 'Test Person applied to Fellowship 2027.')
  end

  it 'substitutes literally, never evaluating or re-expanding what it inserts' do
    tricky = create_applicant(round: round, name: '{{round}} #{1 + 1} <%= 1 %>')
    expect(template(body: 'Hi {{name}}').render(tricky).body).to eq 'Hi {{round}} #{1 + 1} <%= 1 %>'
  end

  it 'keeps the subject to one line whatever is inserted' do
    expect(template(subject: '{{name}}').render(applicant, name: "Two\r\nlines").subject).to eq 'Two lines'
  end

  it 'refuses to render a placeholder with nothing to fill it' do
    nameless = create_applicant(round: round, name: nil)
    expect { template(body: 'Hi {{name}}').render(nameless) }
      .to raise_error(described_class::RenderError, 'The EOI confirmation template uses {{name}}, but this applicant has none')
  end

  it 'refuses unknown placeholders when saved' do
    t = template(subject: 'Hi {{Name}}', body: '{{nickname}} {{name}}')
    expect(t).not_to be_valid
    expect(t.errors[:subject]).to eq ['uses unknown placeholders: {{Name}}']
    expect(t.errors[:body]).to eq ['uses unknown placeholders: {{nickname}}']
  end

  it 'needs a one-line subject and a body, one per type per round' do
    expect(template(subject: "a\nb")).not_to be_valid
    expect(template(body: '')).not_to be_valid
    expect(template(email_type: 'love_letter')).not_to be_valid
    template.save!
    expect(template).not_to be_valid
    expect(described_class.new(round: Fabricate(:admissions_round), email_type: 'confirmation', subject: 'S', body: 'B'))
      .to be_valid
  end

  it 'is found by type on its round' do
    saved = template.tap(&:save!)
    expect(round.email_template('confirmation')).to eq saved
    expect(round.email_template('holding')).to be_nil
    expect { round.email_template('love_letter') }.to raise_error(ArgumentError)
  end
end
