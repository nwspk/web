require 'net/http'

# Posts a submission to a public Google Form's formResponse endpoint and
# reports whether Google actually recorded it. Google returns 200 for both
# success and validation failure (e.g. a stale entry.* field mapping after the
# form was edited), so the only reliable signal is the form's configured
# confirmation message appearing in the response body. A false return means
# "not provably recorded" — callers must treat the submission as undelivered.
#
# Everything Google-shaped belongs in here; callers supply only their own
# answers, keyed by the form's entry.* field ids.
class GoogleFormRelay
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  # Google's default confirmation wording — pass `confirmation:` for a form
  # that has been given its own.
  DEFAULT_CONFIRMATION = 'Your response has been recorded'.freeze

  # Housekeeping fields that every formResponse post carries, regardless of
  # which questions the form asks.
  SUBMISSION_FIELDS = { 'fvv' => '1', 'pageHistory' => '0' }.freeze

  def self.submit(form_id, answers, confirmation: DEFAULT_CONFIRMATION)
    uri = URI("https://docs.google.com/forms/d/e/#{form_id}/formResponse")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                                   open_timeout: OPEN_TIMEOUT,
                                                   read_timeout: READ_TIMEOUT) do |http|
      http.post(uri.path, URI.encode_www_form(SUBMISSION_FIELDS.merge(answers)))
    end
    response.code == '200' && response.body.include?(confirmation)
  rescue StandardError => e
    Rails.logger.error("GoogleFormRelay: #{e.class}: #{e.message}")
    false
  end

  # Google wants a date-time answer as five separately-named parts rather than
  # one string. Takes a browser datetime-local value; returns {} for anything
  # else, so an unanswered optional date simply contributes no fields.
  def self.date_time_fields(entry_id, value)
    match = value.to_s.match(/\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})T(?<hour>\d{2}):(?<minute>\d{2})/)
    return {} unless match

    match.named_captures.to_h { |part, number| ["#{entry_id}_#{part}", number.to_i.to_s] }
  end
end
