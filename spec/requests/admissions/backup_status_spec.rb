require 'rails_helper'

RSpec.describe 'The nightly backup on the staff home', type: :request do
  let(:lead) { admissions_staff(role: 'lead') }

  def run(outcome, at: Time.current, error: nil, **attrs)
    Admissions::BackupRun.create!(outcome: outcome, started_at: at, finished_at: at, error: error,
                                  content_checksum: outcome == 'failed' ? nil : 'sha256:test', **attrs)
  end

  def staff_home
    sign_in lead
    get '/admissions/staff'
    expect(response).to have_http_status(:ok)
    response.body
  end

  before { create_applicant(by: staff_changes(lead)) }

  it 'shows a failed night as a red warning, which stays until a later night succeeds' do
    run('sent', at: 3.days.ago)
    run('failed', at: 2.days.ago, error: 'the email was not sent: Gmail refused (test)')
    run('failed', at: 1.hour.ago, error: 'the export failed (RuntimeError: test)')

    page = staff_home
    expect(page).to include('alert-danger', 'The nightly backup failed', 'the export failed (RuntimeError: test).')
    expect(page).to include('It has failed every night since', 'The last backup emailed to the leads was taken')

    run('unchanged')
    page = staff_home
    expect(page).not_to include('The nightly backup failed')
    expect(page).to include('Backups: last checked')
  end

  it 'counts an unknown outcome as a failure' do
    run('failed', error: "the email's outcome is unknown, so check the admissions@ Sent folder: lost (test)")
    expect(staff_home).to include('The nightly backup failed', 'check the admissions@ Sent folder',
                                  'No backup has been emailed yet.')
  end

  it 'warns when no backup has run for over a night, or ever' do
    expect(staff_home).to include('alert-danger', 'No nightly backup has run yet.')

    run('sent', at: 2.days.ago)
    expect(staff_home).to include('No nightly backup has run since')

    run('unchanged', at: 2.hours.ago)
    page = staff_home
    expect(page).not_to include('No nightly backup has run')
    expect(page).to include('Backups: last checked', 'and last emailed to the leads')
  end

  it 'warns about nothing before there is any applicant data' do
    allow(Admissions::Applicant).to receive(:exists?).and_return(false)
    expect(staff_home).not_to include('No nightly backup has run')
  end

  it 'says when the last backup was only recorded' do
    run('sent', delivery: 'recording')
    expect(staff_home).to include('(Recording only: nothing actually went out.)')
  end
end
