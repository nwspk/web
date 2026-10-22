module Admissions
  # The wording of one email type in one round (SPEC §4: "all templated,
  # editable per round"). Templates live only in the database: the
  # repository is public, so no admissions wording is ever in code (§9).
  #
  # Text is plain, with a small fixed set of placeholders such as {{name}}.
  # Rendering is a single pass of literal substitution, never evaluated, so
  # nothing a template or an applicant's details contain can run as code or
  # expand into another placeholder.
  class EmailTemplate < ActiveRecord::Base
    PLACEHOLDER = /\{\{\s*(\w+)\s*\}\}/

    # The placeholders a template may use, and what each is filled with.
    PLACEHOLDERS = {
      'name' => "The applicant's name",
      'round' => "The round's name",
      'portal_link' => "The applicant's portal link"
    }.freeze

    class RenderError < StandardError; end

    Rendered = Struct.new(:subject, :body, keyword_init: true)

    belongs_to :round, class_name: 'Admissions::Round', inverse_of: :email_templates
    belongs_to :updated_by_user, class_name: 'User', optional: true

    validates :email_type, inclusion: { in: EmailTypes.keys }, uniqueness: { scope: :round_id }
    validates :subject, :body, presence: true
    validates :subject, length: { maximum: 250 }, format: { without: /[\r\n]/, message: 'must be one line' }
    validate :placeholders_known

    def label = EmailTypes.label(email_type)

    def self.placeholders_in(text)
      text.to_s.scan(PLACEHOLDER).flatten.uniq
    end

    # The subject and body for this applicant. `values` supplies anything
    # the applicant record can't, such as the portal link once the
    # applicant-portal exists. A placeholder with nothing to fill it raises
    # RenderError, so no email goes out with a gap in it.
    def render(applicant, values = {})
      values = default_values(applicant).merge(values.transform_keys(&:to_s))
      Rendered.new(subject: substitute(subject, values).gsub(/[\r\n]+/, ' '), body: substitute(body, values))
    end

    private

    def default_values(applicant)
      { 'name' => applicant.name, 'round' => applicant.round.name }
    end

    def substitute(text, values)
      text.gsub(PLACEHOLDER) do
        key = Regexp.last_match(1)
        value = values[key].presence
        raise RenderError, missing_value_message(key) unless value

        value.to_s
      end
    end

    def missing_value_message(key)
      if key == 'portal_link'
        "The #{label} template uses {{portal_link}}, but applicants have no portal link until the applicant portal is built"
      else
        "The #{label} template uses {{#{key}}}, but this applicant has none"
      end
    end

    def placeholders_known
      %i[subject body].each do |field|
        unknown = self.class.placeholders_in(public_send(field)) - PLACEHOLDERS.keys
        next if unknown.empty?

        errors.add(field, "uses unknown placeholders: #{unknown.map { |k| "{{#{k}}}" }.join(', ')}")
      end
    end
  end
end
