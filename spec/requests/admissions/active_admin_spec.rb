require 'rails_helper'

RSpec.describe 'Admissions in ActiveAdmin (the fallback screens)', type: :request do
  let(:admin_lead) do
    Fabricate(:user, role: 'admin').tap { |u| Fabricate(:admissions_staff_member, user: u, role: 'lead') }
  end
  let!(:round) { Fabricate(:admissions_round, name: 'Fellowship 2027') }
  let!(:applicant) { create_applicant(round: round, stage: 'applied') }

  def resource(name)
    ActiveAdmin.application.namespaces[:admin].resources.find { |r| r.resource_class.name == name }
  end

  it 'registers applicants and the event log read-only: index and show, no forms' do
    expect(resource('Admissions::Applicant').defined_actions).to match_array %i[index show]
    expect(resource('Admissions::ApplicantEvent').defined_actions).to match_array %i[index show]
    expect(resource('Admissions::Round').defined_actions).to include(:new, :create, :edit, :update)
    expect(resource('Admissions::StaffMember').defined_actions).to include(:new, :create, :edit, :update)

    %w[admin/admissions_applicants admin/admissions_applicant_events].each do |controller|
      routed = Rails.application.routes.routes.select { |r| r.defaults[:controller] == controller }
      expect(routed.map { |r| r.defaults[:action] }.uniq).to match_array %w[index show]
      expect(routed.map(&:verb).uniq).to eq ['GET']
    end
  end

  describe 'a site admin who is also admissions staff' do
    before { sign_in admin_lead }

    it 'reads applicants and their event log' do
      get '/admin/admissions_applicants'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(applicant.email)

      get "/admin/admissions_applicants/#{applicant.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Event log', 'created')
      expect(response.body).not_to include('Edit Admissions Applicant', 'Delete Admissions Applicant')

      get '/admin/admissions_applicant_events'
      expect(response).to have_http_status(:ok)
      get "/admin/admissions_applicant_events/#{applicant.events.first.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'edits rounds and staff members' do
      get "/admin/admissions_rounds/#{round.id}/edit"
      expect(response).to have_http_status(:ok)
      patch "/admin/admissions_rounds/#{round.id}", params: { admissions_round: { programme_fee_pence: 300_000 } }
      expect(round.reload.programme_fee_pence).to eq 300_000

      user = Fabricate(:user)
      post '/admin/admissions_staff_members', params: { admissions_staff_member: { user_id: user.id, role: 'officer' } }
      expect(Admissions::StaffMember.for(user)).to be_officer
    end

    it 'cannot delete a round that has applicants' do
      delete "/admin/admissions_rounds/#{round.id}"
      expect(Admissions::Round.where(id: round.id)).to exist
    end
  end

  it 'keeps a site admin without an admissions role out of the admissions screens' do
    sign_in Fabricate(:user, role: 'admin')

    get '/admin'
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Admissions')

    %W[/admin/admissions_applicants /admin/admissions_applicants/#{applicant.id} /admin/admissions_rounds
       /admin/admissions_staff_members /admin/admissions_applicant_events].each do |path|
      get path
      expect(response).to redirect_to('/account'), path
    end
  end

  it 'keeps admissions staff who are not site admins out of ActiveAdmin entirely' do
    sign_in admissions_staff(role: 'lead')

    %W[/admin /admin/admissions_applicants /admin/admissions_applicants/#{applicant.id} /admin/admissions_rounds
       /admin/users].each do |path|
      get path
      expect(response).to redirect_to('/account'), path
    end
    patch "/admin/admissions_rounds/#{round.id}", params: { admissions_round: { name: 'Hijacked' } }
    expect(round.reload.name).to eq 'Fellowship 2027'
  end

  it 'still gives site admins the rest of ActiveAdmin' do
    sign_in Fabricate(:user, role: 'admin')
    get '/admin/users'
    expect(response).to have_http_status(:ok)
  end
end
