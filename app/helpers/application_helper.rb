module ApplicationHelper
  OG_TITLE       = 'Newspeak House'.freeze
  OG_DESCRIPTION = 'The London College of Political Technology'.freeze
  OG_IMAGE       = 'lcpt-roundel-social-card.jpg'.freeze

  # Social preview tags for every page, emitted from layouts/_head. The card is
  # the same site-wide (see CLAUDE.md, "the social card"); a page that needs its
  # own title, description or canonical URL assigns @og_title / @og_description
  # / @og_url and overrides just that part. Defaulting here rather than per page
  # means a new page can't accidentally ship with no preview card at all.
  def social_preview_tags
    tags = [
      tag.meta(property: 'og:title', content: @og_title || OG_TITLE),
      tag.meta(property: 'og:description', content: @og_description || OG_DESCRIPTION),
      tag.meta(property: 'og:image', content: asset_url(OG_IMAGE)),
      tag.meta(name: 'twitter:card', content: 'summary')
    ]
    tags << tag.meta(property: 'og:url', content: @og_url) if @og_url
    safe_join(tags)
  end

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
