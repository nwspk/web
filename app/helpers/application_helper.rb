module ApplicationHelper
  def link_to_in_li(body, url, options = {})
    active = 'active' if current_page?(url)

    content_tag :li, class: active do
      link_to body, url, options
    end
  end
end
