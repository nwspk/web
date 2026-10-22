require 'rails_helper'

RSpec.describe Admissions::Backup do
  let(:lead) { admissions_staff(role: 'lead', user: Fabricate(:user, email: 'lead@example.com')) }
  let(:officer) { admissions_staff(role: 'officer', user: Fabricate(:user, email: 'officer@example.com')) }
  let(:connection) { ActiveRecord::Base.connection }

  # Something in every admissions table: two rounds with a returning
  # applicant, a template, wording, staff, applicants in several states,
  # an email sent and one held, notes, a hold, a flag, a withdrawal, and a
  # backup run.
  def invented_data
    earlier = Fabricate(:admissions_round, name: 'Backup test 2026')
    round = Fabricate(:admissions_round, name: 'Backup test 2027')
    Admissions::FormText.create!(key: 'privacy_notice', body: 'Test privacy notice.', created_by_user: lead)
    email_template(round, 'confirmation')
    by_lead = staff_changes(lead)
    by_officer = staff_changes(officer)
    returning = create_applicant(round: earlier, email: 'returning@example.com', by: by_lead)
    again = create_applicant(round: round, email: 'Returning@example.com', previous_applicant: returning, by: by_lead)
    staff_sender(lead).send_now!(again, 'confirmation')
    by_officer.add_note!(again, body: 'Test note ✓ with ünïcode')
    held = create_applicant(round: round, stage: 'applied', by: by_officer)
    system_sender.request_automatic!(held, 'confirmation')
    by_officer.hold!(held, until_date: Date.current + 10, reason: 'Test hold reason')
    flagged = create_applicant(round: round, by: by_officer)
    by_lead.flag_complicated!(flagged, note: 'Test complication', check_back_on: Date.current + 3)
    by_lead.withdraw!(create_applicant(round: round, by: by_officer))
    Admissions::BackupRun.create!(outcome: 'unchanged', started_at: 2.days.ago, finished_at: 2.days.ago,
                                  content_checksum: 'sha256:earlier')
    round
  end

  # Each table's rows, exactly as Postgres holds them.
  def table_rows
    described_class::TABLES.index_with do |table|
      connection.select_value("SELECT coalesce(json_agg(r ORDER BY r.id), '[]'::json)::text FROM #{table} r")
    end
  end

  def archive = described_class::Archive.build(described_class::Snapshot.take)

  def restore(bytes, **options) = described_class::Restore.new(bytes, **options).run

  # Empties every admissions table, past the guards, as a lost database
  # would be.
  def wipe!
    described_class::TABLES.reverse_each do |table|
      connection.execute("ALTER TABLE #{table} DISABLE TRIGGER USER")
      connection.execute("DELETE FROM #{table}")
      connection.execute("ALTER TABLE #{table} ENABLE TRIGGER USER")
    end
  end

  it 'covers every admissions table in the database' do
    expect(described_class::TABLES.sort).to eq described_class.tables_in_database
  end

  it 'refuses to export while an admissions table is missing from TABLES, rather than leave it out' do
    allow(described_class).to receive(:tables_in_database).and_return(described_class::TABLES + ['admissions_new'])
    expect { described_class::Snapshot.take }.to raise_error(described_class::Error, /admissions_new is not in/)
  end

  describe 'the file' do
    before { invented_data }

    it 'has a header naming the schema, the time, the row counts and the checksum' do
      file = archive
      text = Zlib::GzipReader.new(StringIO.new(file.bytes)).read.force_encoding('UTF-8')
      header_line, data_line = text.split("\n")
      header = JSON.parse(header_line)

      expect(header).to include('format' => 'nwspk-admissions-backup', 'format_version' => 1,
                                'schema_version' => connection.pool.migration_context.current_version)
      expect(Time.iso8601(header['taken_at'])).to be_within(1.minute).of(Time.current)
      counts = described_class::TABLES.index_with { |t| connection.select_value("SELECT count(*) FROM #{t}") }
      expect(header['row_counts']).to eq counts
      expect(header['row_counts']).to all(satisfy { |_, n| n.positive? })
      expect(header['checksum']).to eq "sha256:#{Digest::SHA256.hexdigest(data_line)}"
      expect(file.filename).to match(/\Aadmissions-backup-\d{4}-\d\d-\d\dT\d{4}Z\.jsonl\.gz\z/)
    end

    it 'holds every row of every admissions table, as Postgres does' do
      data = JSON.parse(Zlib::GzipReader.new(StringIO.new(archive.bytes)).read.split("\n").last)
      described_class::TABLES.each do |table|
        expect(data['tables'][table]).to eq(JSON.parse(table_rows[table])), table
      end
      bodies = data['tables']['admissions_applicant_events'].map { |e| e['body'] }
      expect(bodies).to include('Test note ✓ with ünïcode')
    end

    it 'holds only the id and email of the staff users the rows point to' do
      bystander = Fabricate(:user, email: 'bystander@example.com')
      expect(archive.users).to eq([lead, officer].sort_by(&:id).map { |u| { 'id' => u.id, 'email' => u.email } })
      expect(archive.users.map { |u| u['email'] }).not_to include(bystander.email)
    end

    it 'reads back only when whole and unchanged' do
      bytes = archive.bytes
      expect(described_class::Archive.read(bytes).row_counts).to eq archive.row_counts

      text = Zlib::GzipReader.new(StringIO.new(bytes)).read
      tampered = described_class::Archive.send(:gzip, text.sub('Test note', 'Test edit'))
      expect { described_class::Archive.read(tampered) }
        .to raise_error(described_class::Archive::Invalid, /checksum doesn't match/)
      expect { described_class::Archive.read('not gzip') }
        .to raise_error(described_class::Archive::Invalid, /isn't gzipped/)
      expect { described_class::Archive.read(described_class::Archive.send(:gzip, "{\"format\":\"x\"}\n{}")) }
        .to raise_error(described_class::Archive::Invalid, /isn't an admissions backup/)
    end
  end

  describe 'the content checksum' do
    before { invented_data }

    it 'stays the same while nothing changes, ignoring the backup log' do
      first = described_class::Snapshot.take.content_checksum
      Admissions::BackupRun.create!(outcome: 'unchanged', started_at: Time.current, finished_at: Time.current,
                                    content_checksum: first)
      expect(described_class::Snapshot.take.content_checksum).to eq first
    end

    it 'changes with any change to the data' do
      first = described_class::Snapshot.take.content_checksum
      staff_changes(lead).add_note!(Admissions::Applicant.first, body: 'Another test note')
      expect(described_class::Snapshot.take.content_checksum).not_to eq first
    end
  end

  describe 'the round trip: export, wipe, restore' do
    it 'puts back every table row for row, and the state rebuilder agrees with every applicant' do
      invented_data
      before = table_rows
      bytes = archive.bytes
      applicants = Admissions::Applicant.count

      wipe!
      expect(described_class::TABLES.map { |t| connection.select_value("SELECT count(*) FROM #{t}") }).to all(eq 0)

      result = restore(bytes)

      expect(table_rows).to eq before
      expect(result.row_counts).to eq(before.transform_values { |rows| JSON.parse(rows).size })
      expect(result.users_matched).to eq 2
      expect(result.inconsistent).to be_empty
      expect(Admissions::Applicant.count).to eq applicants
      expect(Admissions::StateRebuilder.inconsistent).to be_empty
    end

    it 'keeps the guards on, and new rows follow on from the restored ids' do
      round = invented_data
      bytes = archive.bytes
      wipe!
      restore(bytes)

      expect_refused(ActiveRecord::StatementInvalid, /append-only/) do
        Admissions::ApplicantEvent.update_all(body: 'changed')
      end
      expect_refused(ActiveRecord::StatementInvalid, /never deleted/) { Admissions::Applicant.delete_all }
      expect_refused(ActiveRecord::StatementInvalid, /only through/) do
        Admissions::Applicant.update_all(stage: 'applied')
      end
      newest = Admissions::Applicant.maximum(:id)
      expect(create_applicant(round: round, by: staff_changes(lead)).id).to be > newest
    end

    it 'maps staff users by email to the users here' do
      invented_data
      bytes = archive.bytes
      events_by_lead = Admissions::ApplicantEvent.where(actor_user: lead).count
      wipe!
      # The same person, under another id on this site (any case).
      lead.update_columns(email: 'old-lead@example.com')
      moved = Fabricate(:user, email: 'LEAD@example.com')

      restore(bytes)

      expect(Admissions::ApplicantEvent.where(actor_user: moved).count).to eq events_by_lead
      expect(Admissions::StaffMember.find_by(user: moved)).to be_lead
      expect(Admissions::ApplicantEvent.where(actor_user: lead)).to be_empty
    end

    it 'erases what is there first only when told to, and restores the file in its place' do
      round = invented_data
      before = table_rows
      bytes = archive.bytes
      create_applicant(round: round, by: staff_changes(lead))

      result = restore(bytes, erase_existing: true)

      expect(result.erased_counts['admissions_applicants']).to eq Admissions::Applicant.count + 1
      expect(table_rows).to eq before
    end
  end

  describe 'what the restore refuses' do
    let!(:bytes) { invented_data && archive.bytes }

    def refused(bytes, message, **options)
      expect_refused(described_class::Restore::Refused, message) { restore(bytes, **options) }
    end

    it 'refuses a database whose admissions tables are not empty, naming the flag' do
      before = table_rows
      refused(bytes, /admissions tables aren't empty \(.*admissions_applicants: 5.*ERASE_CURRENT_ADMISSIONS_DATA=yes/)
      expect(table_rows).to eq before
    end

    it 'refuses a file whose checksum does not match' do
      wipe!
      text = Zlib::GzipReader.new(StringIO.new(bytes)).read
      refused(described_class::Archive.send(:gzip, text.sub('Test hold reason', 'Test held reason')),
              /checksum doesn't match/)
      expect(Admissions::Applicant.count).to eq 0
    end

    it 'refuses a file taken at another schema version' do
      wipe!
      allow(described_class).to receive(:schema_version).and_return(20_991_231_000_000)
      refused(bytes, /taken at schema version \d+, and this database is at 20991231000000/)
    end

    it 'refuses a file whose columns are not this database’s' do
      wipe!
      text = Zlib::GzipReader.new(StringIO.new(bytes)).read
      header, data = text.split("\n")
      data = JSON.parse(data)
      data['tables']['admissions_rounds'].each { |r| r['surprise'] = 1 }
      line = JSON.generate(data)
      header = JSON.parse(header).merge('checksum' => described_class.sha256(line))
      refused(described_class::Archive.send(:gzip, "#{JSON.generate(header)}\n#{line}\n"),
              /admissions_rounds columns don't match/)
    end

    it 'refuses when a staff user has no account here, naming them, and restores nothing' do
      wipe!
      officer.update_columns(email: 'renamed@example.com')
      refused(bytes, /this staff user has no account on this site: officer@example.com/)
      expect(Admissions::Round.count).to eq 0
    end
  end

  describe Admissions::Backup::Nightly do
    let(:runs) { Admissions::BackupRun.order(:id) }

    before do
      invented_data
      officer
      admissions_staff(role: 'lead', user: Fabricate(:user, email: 'second-lead@example.com'))
      Admissions::Delivery::Recording.clear! # the applicant email the data includes
    end

    def nightly(**options) = described_class.new(**options).run

    it 'emails the file to every lead, and only the leads, through the recording delivery' do
      run = nightly

      expect(run).to have_attributes(outcome: 'sent', delivery: 'recording', error: nil)
      expect(recorded_emails.size).to eq 1
      message = recorded_emails.first
      expect(message.to).to eq 'lead@example.com, second-lead@example.com'
      expect(message.to).not_to include('officer@example.com')
      expect(run.recipients).to eq %w[lead@example.com second-lead@example.com]
      expect(message.subject).to eq "Admissions backup, #{Time.current.strftime('%-d %B %Y')}"
      expect(message.body).to start_with('Here is the first backup of the admissions data, attached.')
      expect(message.body).to include('- Backup test 2026: 1 applicant', '- Backup test 2027: 4 applicants',
                                      run.file_name, run.file_checksum, 'bin/rails admissions:backup:restore')
      file = message.attachment
      expect(file).to have_attributes(filename: run.file_name, content_type: 'application/gzip')
      expect(file.content.bytesize).to eq run.file_bytes
      expect(Admissions::Backup::Archive.read(file.content).checksum).to eq run.file_checksum
    end

    it 'sends nothing on a night when nothing changed, and one email once something has' do
      nightly
      expect(nightly).to have_attributes(outcome: 'unchanged', file_name: nil)
      expect(recorded_emails.size).to eq 1

      staff_changes(lead).add_note!(Admissions::Applicant.first, body: 'Another test note')
      expect(nightly).to be_sent
      expect(recorded_emails.size).to eq 2
      expect(recorded_emails.last.body).to start_with('The admissions data has changed since the last backup')
      expect(nightly).to be_unchanged
      expect(runs.map(&:outcome)).to eq %w[unchanged sent unchanged sent unchanged]
    end

    it 'records a failed export, and tries again the next night' do
      allow(Admissions::Backup::Snapshot).to receive(:take).and_raise(ActiveRecord::StatementInvalid, 'test failure')
      run = nightly
      expect(run).to have_attributes(outcome: 'failed', content_checksum: nil)
      expect(run.error).to eq 'the export failed (ActiveRecord::StatementInvalid: test failure)'
      expect(recorded_emails).to be_empty

      allow(Admissions::Backup::Snapshot).to receive(:take).and_call_original
      expect(nightly).to be_sent
    end

    it 'refuses a file too big for one email rather than send part of it' do
      stub_const("#{described_class}::MAX_FILE_BYTES", 100)
      run = nightly
      expect(run).to be_failed
      expect(run.error)
        .to match(/\Athe backup file is .+, more than the 100 Bytes that fits in one email, so it was not sent\z/)
      expect(run.file_bytes).to be > 100
      expect(recorded_emails).to be_empty
    end

    it 'records a delivery that certainly failed' do
      refusing = Class.new { def deliver(_) = raise(Admissions::Delivery::NotSent, 'Gmail refused (test)') }.new
      expect(nightly(delivery: refusing)).to have_attributes(
        outcome: 'failed', error: 'the email was not sent: Gmail refused (test)'
      )
      expect(nightly).to be_sent
    end

    it 'records a delivery whose outcome is unknown as a failure, and sends again the next night' do
      unknown = Class.new { def deliver(_) = raise(Admissions::Delivery::OutcomeUnknown, 'connection lost (test)') }.new
      run = nightly(delivery: unknown)
      expect(run).to be_failed
      expect(run.error)
        .to eq "the email's outcome is unknown, so check the admissions@ Sent folder: connection lost (test)"
      expect(Admissions::BackupRun.last_sent).to be_nil
      expect(nightly).to be_sent
    end

    it 'records production without Gmail configured as a failure, naming the missing variables' do
      Admissions::Delivery.adapter = nil
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      run = nightly
      expect(run.error).to match(/\Athe email was not sent: Gmail delivery is not configured: set ADMISSIONS_GMAIL_/)
    ensure
      Admissions::Delivery.adapter = nil
    end

    it 'fails when there is no lead to send to' do
      Admissions::StaffMember.where(role: 'lead').delete_all
      expect(nightly).to have_attributes(outcome: 'failed', error: 'there is no admissions lead to send it to')
    end

    it 'keeps the backup log append-only' do
      run = nightly
      expect_refused(ActiveRecord::StatementInvalid, /backup log is append-only/) do
        Admissions::BackupRun.where(id: run.id).update_all(outcome: 'failed', error: 'x')
      end
      expect_refused(ActiveRecord::StatementInvalid, /backup log is append-only/) do
        Admissions::BackupRun.where(id: run.id).delete_all
      end
      expect_refused(ActiveRecord::StatementInvalid, /backup log is append-only/) do
        connection.execute('TRUNCATE admissions_backup_runs')
      end
    end

    it 'never reaches a real network, even through the Gmail adapter' do
      env = { 'ADMISSIONS_GMAIL_CLIENT_ID' => 'fake-id', 'ADMISSIONS_GMAIL_CLIENT_SECRET' => 'fake-secret',
              'ADMISSIONS_GMAIL_REFRESH_TOKEN' => 'fake-refresh' }
      run = nightly(delivery: Admissions::Delivery::Gmail.new(env: env))
      expect(run.error).to eq 'the email was not sent: Gmail could not be reached (RuntimeError)'
    end
  end
end
