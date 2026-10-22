module Admissions
  module Backup
    # The nightly backup (Q34), run once a night by
    # `bin/rails admissions:backup:nightly`:
    #
    # 1. take a snapshot of the admissions data;
    # 2. if its content checksum equals the last emailed backup's, record
    #    the night as unchanged and send nothing;
    # 3. otherwise build the file, refuse it if it is too big for one email,
    #    and email it from admissions@ to every admissions lead through the
    #    email-sender's delivery (recording only, in test and development);
    # 4. record the run, whatever happened, as one BackupRun.
    #
    # This is staff mail, not applicant mail: it doesn't go through the
    # outbox or the templates, and its wording lives here. A failure at any
    # step, a delivery whose outcome is unknown included, is recorded as a
    # failed run and shown on the staff home until a later night succeeds;
    # the next night then tries again, since the last emailed backup is
    # still the older one.
    class Nightly
      # Gmail takes messages up to 25 MB, counted after the attachment is
      # base64-encoded, which makes it a third bigger.
      MAX_FILE_BYTES = 18.megabytes

      class TooLarge < Error; end
      class NoRecipients < Error; end

      def initialize(delivery: nil)
        @delivery = delivery
      end

      # Returns the recorded BackupRun.
      def run
        @started_at = Time.current
        @step = :export
        snapshot = Snapshot.take
        last_sent = BackupRun.last_sent
        return record('unchanged', snapshot: snapshot) if last_sent&.content_checksum == snapshot.content_checksum

        @step = :file
        archive = Archive.build(snapshot)
        check_size!(archive)
        recipients = Backup.recipients
        raise NoRecipients, 'there is no admissions lead to send it to' if recipients.empty?

        @step = :delivery
        mail = message(snapshot, archive, recipients, first: last_sent.nil?)
        receipt = (@delivery || Delivery.adapter).deliver(mail)
        record('sent', snapshot: snapshot, archive: archive, recipients: recipients, receipt: receipt)
      rescue StandardError => e
        record('failed', snapshot: snapshot, archive: archive, recipients: recipients, error: describe(e))
      end

      private

      def check_size!(archive)
        size = archive.bytes.bytesize
        return if size <= MAX_FILE_BYTES

        raise TooLarge, "the backup file is #{human_size(size)}, more than the #{human_size(MAX_FILE_BYTES)} " \
                        'that fits in one email, so it was not sent'
      end

      def describe(error)
        case error
        when TooLarge, NoRecipients then error.message
        when Delivery::OutcomeUnknown
          "the email's outcome is unknown, so check the admissions@ Sent folder: #{error.message}"
        when Delivery::NotSent then "the email was not sent: #{error.message}"
        else
          what = { export: 'the export', file: 'building the file', delivery: 'sending the email' }.fetch(@step)
          "#{what} failed (#{error.class}: #{error.message})"
        end
      end

      def record(outcome, snapshot: nil, archive: nil, recipients: nil, receipt: nil, error: nil)
        run = BackupRun.create!(
          outcome: outcome, started_at: @started_at, finished_at: Time.current, error: error,
          schema_version: snapshot&.schema_version, content_checksum: snapshot&.content_checksum,
          row_counts: snapshot&.row_counts || {}, recipients: recipients || [],
          file_name: archive&.filename, file_checksum: archive&.checksum, file_bytes: archive&.bytes&.bytesize,
          delivery: receipt&.delivery, delivery_message_id: receipt&.message_id
        )
        log(run)
        run
      end

      def log(run)
        line = "[admissions] backup run ##{run.id}: #{run.outcome}"
        run.failed? ? Rails.logger.error("#{line}: #{run.error}") : Rails.logger.info(line)
      end

      def message(snapshot, archive, recipients, first:)
        Delivery::Message.new(
          to: recipients.join(', '), subject: subject(snapshot), body: body(snapshot, archive, first: first),
          attachment: Delivery::Attachment.new(filename: archive.filename, content_type: Archive::CONTENT_TYPE,
                                               content: archive.bytes)
        )
      end

      def subject(snapshot) = "Admissions backup, #{snapshot.taken_at.in_time_zone.strftime('%-d %B %Y')}"

      def body(snapshot, archive, first:)
        rounds = snapshot.applicants_per_round.map do |name, count|
          "- #{name}: #{count} #{count == 1 ? 'applicant' : 'applicants'}"
        end
        taken = snapshot.taken_at.in_time_zone.strftime('%-d %B %Y at %H:%M')
        opening = if first
                    'Here is the first backup of the admissions data, attached.'
                  else
                    'The admissions data has changed since the last backup, so here is a new one, attached.'
                  end
        <<~TEXT
          #{opening}

          Rounds:
          #{rounds.any? ? rounds.join("\n") : '- none yet'}

          File: #{archive.filename}, #{human_size(archive.bytes.bytesize)}
          Checksum: #{archive.checksum}
          Taken: #{taken} (London time), at schema version #{snapshot.schema_version}

          Keep this email: these emails are the backup history. To restore from this file, someone with access to the server runs:

            bin/rails admissions:backup:restore FILE=#{archive.filename}

          The file isn't encrypted and holds applicants' personal details, so keep it within the admissions staff.
        TEXT
      end

      def human_size(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end
end
