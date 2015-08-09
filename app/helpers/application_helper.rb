module ApplicationHelper
  def link_to_in_li(body, url, options = {})
    active = 'active' if current_page?(url)

    content_tag :li, class: active do
      link_to body, url, options
    end
  end

  def canonical_path
    CANONICAL_HOST.blank? ? request.original_url : CANONICAL_HOST + "#{request.fullpath}"
  end

  def plaintext_list_user_item(u)
    [u.name, "#{u.showcase_text} #{u.url}"].map { |x| x.strip.blank? ? nil : x.strip }.compact.join("\n  ")
  end
end
