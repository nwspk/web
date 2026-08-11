require 'net/http'

# Posts a submission to a public Google Form's formResponse endpoint and
# reports whether Google actually recorded it. Google returns 200 for both
# success and validation failure (e.g. a stale entry.* field mapping after the
# form was edited), so the only reliable signal is the form's configured
# confirmation message appearing in the response body. A false return means
# "not provably recorded" — callers must treat the submission as undelivered.
class GoogleFormRelay
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  def self.submit(form_id, fields, confirmation:)
    uri = URI("https://docs.google.com/forms/d/e/#{form_id}/formResponse")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    response = http.post(uri.path, URI.encode_www_form(fields))
    response.code == '200' && response.body.include?(confirmation)
  rescue StandardError => e
    Rails.logger.error("GoogleFormRelay: #{e.class}: #{e.message}")
    false
  end
end
