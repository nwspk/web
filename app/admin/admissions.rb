# The admissions fallback screens (SPEC §9 "Fallback UI"), for when the
# /admissions area misbehaves. Rounds and staff members are editable here.
# Applicants and their event log are read-only: every change to them goes
# through Admissions::ApplicantChanges, and the database refuses anything
# else.

ActiveAdmin.register Admissions::Round, as: 'Admissions Round' do
  menu parent: 'Admissions', label: 'Rounds'
  config.batch_actions = false

  permit_params :name, :opens_on, :invites_on, :closes_on, :closed_at, :reminder_interval_days,
                :programme_fee_pence, :accommodation_monthly_pence, :scholarship_pot_pence

  filter :name

  index do
    column :name
    column :opens_on
    column :invites_on
    column :closes_on
    column :closed_at
    column(:applicants) { |r| r.applicants.count }
    actions
  end

  show do
    attributes_table do
      row :name
      row :opens_on
      row :invites_on
      row :closes_on
      row :closed_at
      row(:programme_fee) { |r| r.programme_fee&.format }
      row(:accommodation_monthly) { |r| r.accommodation_monthly&.format }
      row(:scholarship_pot) { |r| r.scholarship_pot&.format }
      row :reminder_interval_days
      row(:staff_turnaround_days) { |r| Admissions::Round.staff_stages.map { |s| "#{s}: #{r.staff_turnaround(s).in_days.to_i}" }.join(', ') }
      row(:email_modes) { |r| Admissions::EmailTypes.keys.map { |t| "#{t}: #{r.email_mode(t)}" }.join(', ') }
    end
  end

  controller do
    def destroy
      destroy!
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_admissions_rounds_path, flash: { error: 'Cannot delete a round that has applicants' }
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    inputs do
      input :name
      input :opens_on, as: :datepicker
      input :invites_on, as: :datepicker
      input :closes_on, as: :datepicker
      input :closed_at
      input :programme_fee_pence, label: 'Programme fee in pence'
      input :accommodation_monthly_pence, label: 'Accommodation per month in pence'
      input :scholarship_pot_pence, label: 'Scholarship pot in pence'
      input :reminder_interval_days
    end

    para 'Email modes and staff turnarounds are edited at /admissions.'

    actions
  end
end

ActiveAdmin.register Admissions::StaffMember, as: 'Admissions Staff Member' do
  menu parent: 'Admissions', label: 'Staff'
  config.batch_actions = false

  permit_params :user_id, :role

  # Whoever grants or changes a role is recorded against it.
  before_save { |member| member.granted_by_user = current_user }

  filter :role, as: :select, collection: Admissions::StaffMember::ROLES

  index do
    column(:user) { |m| link_to m.user.name, admin_user_path(m.user) }
    column(:email) { |m| m.user.email }
    column(:role) { |m| status_tag m.role }
    column('Granted by') { |m| m.granted_by_user&.name || 'Not recorded' }
    column('Granted') { |m| m.updated_at }
    actions
  end

  show do
    attributes_table do
      row :user
      row :role
      row('Granted by') { |m| m.granted_by_user&.name || 'Not recorded' }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    inputs do
      input :user, collection: User.order(:name).map { |u| ["#{u.name} (#{u.email})", u.id] }
      input :role, as: :select, collection: Admissions::StaffMember::ROLES, include_blank: false
    end

    actions
  end
end

ActiveAdmin.register Admissions::Applicant, as: 'Admissions Applicant' do
  menu parent: 'Admissions', label: 'Applicants'
  config.batch_actions = false
  actions :index, :show

  filter :round
  filter :stage, as: :select, collection: Admissions::Stages::ALL
  filter :complicated
  filter :email
  filter :name

  index do
    id_column
    column :round
    column :name
    column :email
    column(:stage) { |a| status_tag a.stage }
    column :complicated
    column :stage_entered_at
    actions
  end

  show do
    attributes_table do
      row :round
      row :name
      row :email
      row :phone
      row :stage
      row :stage_entered_at
      row :held_from_stage
      row :hold_reason
      row :hold_until
      row :exited_from_stage
      row :complicated
      row :complicated_note
      row :complicated_check_back_on
      row :previous_applicant
      row(:log_agrees) { |a| Admissions::StateRebuilder.consistent?(a) ? 'yes' : 'NO: cached state disagrees with the event log' }
    end

    panel 'Event log' do
      table_for resource.events do
        column :created_at
        column :kind
        column :actor_type
        column :actor_user
        column :from_stage
        column :to_stage
        column :details
        column :body
        column :redacted_at
      end
    end
  end
end

ActiveAdmin.register Admissions::ApplicantEvent, as: 'Admissions Applicant Event' do
  menu parent: 'Admissions', label: 'Event log'
  config.batch_actions = false
  config.sort_order = 'id_desc'
  actions :index, :show

  filter :applicant_id
  filter :kind, as: :select, collection: Admissions::ApplicantEvent::KINDS
  filter :actor_type, as: :select, collection: Admissions::Stages::ACTOR_TYPES
  filter :created_at

  index do
    id_column
    column :created_at
    column :applicant
    column :kind
    column :actor_type
    column :actor_user
    column :from_stage
    column :to_stage
    actions
  end
end
