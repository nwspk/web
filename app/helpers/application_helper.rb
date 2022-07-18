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
    [u.name, u.showcase_text, u.url, u.twitter.try(:profile_url)].map { |x| (x.nil? || x.strip.blank?) ? nil : x.strip }.compact.join(", ")
  end

  def simple_vertical_form_for(resource, options = {}, &block)
    options = options.merge(html: { class: 'form-vertical' }, wrapper: :vertical_form, wrapper_mappings: { boolean: :vertical_boolean })
    simple_form_for(resource, options, &block)
  end
end
