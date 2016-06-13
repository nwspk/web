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
    [u.name, u.showcase_text, u.url].map { |x| x.strip.blank? ? nil : x.strip }.compact.join(", ")
  end

  def positivize_zero_val(val)
    rule = { symbol_before_without_space: false, sign_before_symbol: true, sign_positive: true }

    if val.cents != 0
      return val.format(rule)
    else
      return "+#{val.format(rule)}"
    end
  end

  def top_left_link_to(text, path)
    link_to text, path, class: 'top-left-link'
  end

  def top_right_link_to(path)
    link_to fa_icon('chevron-right'), path, class: 'top-right-link'
  end

  def side_link_to(path)
    link_to fa_icon('angle-double-right'), path, class: 'side-link'
  end

  def simple_vertical_form_for(resource, options = {}, &block)
    options = options.merge(html: { class: 'form-vertical' }, wrapper: :vertical_form, wrapper_mappings: { boolean: :vertical_boolean })
    simple_form_for(resource, options, &block)
  end
end
