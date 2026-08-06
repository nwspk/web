module ApplicationHelper
  # Render user-supplied Markdown, then strip any dangerous HTML that Kramdown
  # passed through verbatim (Kramdown does not escape raw HTML by default).
  def safe_markdown(text)
    sanitize(Kramdown::Document.new(text.to_s).to_html)
  end

  # Only allow http(s) links from user-supplied URLs. Returns nil for anything
  # else (e.g. a "javascript:" scheme), so callers can render plain text instead
  # of an executable link.
  def safe_external_url(url)
    url.to_s.match?(%r{\Ahttps?://}i) ? url : nil
  end

  # Sanitize a fellow bio while preserving the Cloudflare-style obfuscated-email
  # markup (span.__cf_email__ + data-cfemail). The hex stays encoded in the HTML
  # source — bots see only "[email protected]" — and app/assets/javascripts
  # decodes it into a real mailto link in the browser.
  def safe_bio(html)
    sanitize(html.to_s, attributes: %w[href class data-cfemail title target rel])
  end
end
