ActiveAdmin.register Event do
  permit_params :name, :start_at, :end_at, :url, :location, :organiser_name, :organiser_email, :organiser_url, :description, :short_description, :notes, :public, :status, :value

  filter :name
  filter :start_at
  filter :location
  filter :organiser_name
  filter :organiser_email

  scope :all
  scope :proposed
  scope :confirmed
  scope :rejected
  scope :upcoming
  scope :archive

  index do
    selectable_column

    column(:name) { |e| link_to e.name, admin_event_path(e) }
    column :start_at
    column :location
    column :public
    column(:status) { |e| status_tag e.status }
    column(:value) { |e| e.money_value.format }

    actions do |event|
      item 'Copy', new_admin_event_path(copy_from: event.id), class: 'member_link'
    end
  end

  controller do
    def new
      if params.has_key?(:copy_from)
        original = Event.find(params.delete(:copy_from).to_i)
        params[:event] = original.attributes
        [:id, :created_at, :updated_at].each { |k| params[:event].delete(k) }
      end

      super
    end
  end

  show do
    attributes_table do
      row :name
      row :location
      row :start_at
      row :end_at
      row :url
      row :public

      row :status do
        status_tag event.status
      end

      row :organiser_name
      row :organiser_email
      row :organiser_url

      row :short_description do
        Kramdown::Document.new(event.short_description).to_html.html_safe
      end

      row :description do
        Kramdown::Document.new(event.description).to_html.html_safe
      end

      row :notes

      row :value do
        event.money_value.format
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    if f.object.new_record? && f.object.start_at.nil? && f.object.end_at.nil?
      today = Time.now.utc.to_date
      f.object.start_at = Time.new(today.year, today.month, today.day, 19, 00, 00, 00)
      f.object.end_at   = Time.new(today.year, today.month, today.day, 22, 00, 00, 00)
    end

    inputs 'Event information' do
      input :name
      input :location, input_html: { rows: 2 }
      input :url
      input :start_at
      input :end_at
      input :short_description, hint: 'You can use the Markdown syntax for rich text formatting'
      input :description, hint: 'You can use the Markdown syntax for rich text formatting'
    end

    inputs 'Organiser information' do
      input :organiser_name
      input :organiser_email
      input :organiser_url
    end

    inputs 'Meta' do
      input :public
      input :status, as: :select, collection: Event.statuses.keys, include_blank: false
      input :value, label: 'Value (ex. VAT) in cents'
      input :notes, input_html: { rows: 3 }
    end

    actions
  end
end
