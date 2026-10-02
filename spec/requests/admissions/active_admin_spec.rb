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

  describe 'a site admin without an admissions role' do
    let(:admin) { Fabricate(:user, role: 'admin') }

    before { sign_in admin }

    it 'is kept out of applicants, the event log and rounds' do
      get '/admin'
      expect(response).to have_http_status(:ok)
      %w[admissions_applicants admissions_applicant_events admissions_rounds].each do |path|
        expect(response.body).not_to include("/admin/#{path}")
      end

      %W[/admin/admissions_applicants /admin/admissions_applicants/#{applicant.id} /admin/admissions_rounds
         /admin/admissions_rounds/#{round.id}/edit /admin/admissions_applicant_events
         /admin/admissions_applicant_events/#{applicant.events.first.id}].each do |path|
        get path
        expect(response).to redirect_to('/account'), path
      end
      patch "/admin/admissions_rounds/#{round.id}", params: { admissions_round: { name: 'Hijacked' } }
      expect(round.reload.name).to eq 'Fellowship 2027'
    end

    it 'can grant the first lead, and the grant records who made it' do
      get '/admin/admissions_staff_members'
      expect(response).to have_http_status(:ok)
      get '/admin/admissions_staff_members/new'
      expect(response).to have_http_status(:ok)

      first_lead = Fabricate(:user, name: 'First Lead')
      post '/admin/admissions_staff_members', params: { admissions_staff_member: { user_id: first_lead.id, role: 'lead' } }
      member = Admissions::StaffMember.for(first_lead)
      expect(member).to be_lead
      expect(member.granted_by_user).to eq admin

      get '/admin/admissions_staff_members'
      expect(response.body).to include('Granted by', admin.name)
    end

    it 'records whoever changes a role, and can remove one' do
      member = Fabricate(:admissions_staff_member, role: 'officer')
      patch "/admin/admissions_staff_members/#{member.id}", params: { admissions_staff_member: { role: 'lead' } }
      expect(member.reload).to have_attributes(role: 'lead', granted_by_user: admin)

      delete "/admin/admissions_staff_members/#{member.id}"
      expect(Admissions::StaffMember.where(id: member.id)).not_to exist
    end

    it 'gets no way into /admissions from managing staff' do
      get '/admissions'
      expect(response).to have_http_status(:not_found)
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
