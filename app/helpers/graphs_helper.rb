module GraphsHelper
  def date_range_select
    select_tag 'date_range', options_for_select([['All', 'all'], ['Past month', 'month'], ['Past week', 'week'], ['Past day', 'day']], @date_range), class: 'form-control'
  end
end
