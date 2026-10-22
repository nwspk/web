# Backups of the admissions data (Admissions::Backup; nwspk/admit SPEC Q34).
# `nightly` is the one the server runs, once a night; the others are for
# people: checking a file, writing one out, and restoring one.
namespace :admissions do
  namespace :backup do
    desc 'Email the admissions data to the admissions leads if it changed since the last backup (run nightly)'
    task nightly: :environment do
      run = Admissions::Backup::Nightly.new.run
      case run.outcome
      when 'sent'
        puts "Backup sent to #{run.recipients.join(', ')}: #{run.file_name}, " \
             "#{run.file_bytes} bytes, #{run.file_checksum}"
        puts '(Recording only: nothing actually went out.)' if run.recording?
      when 'unchanged'
        puts 'Nothing changed since the last backup, so nothing was sent.'
      else
        abort "Backup failed: #{run.error}"
      end
    end

    desc 'Check a backup file without touching the database: FILE=path'
    task check: :environment do
      archive = Admissions::Backup::Archive.read(File.binread(backup_file))
      puts "#{backup_file}: a whole, unchanged admissions backup."
      puts backup_summary(archive)
    rescue Admissions::Backup::Archive::Invalid => e
      abort "#{backup_file} can't be restored: #{e.message}."
    end

    desc 'Write a backup file without emailing or recording it: FILE=path'
    task export: :environment do
      archive = Admissions::Backup::Archive.build(Admissions::Backup::Snapshot.take)
      File.binwrite(backup_file, archive.bytes)
      puts "Wrote #{backup_file} (#{archive.bytes.bytesize} bytes)."
      puts backup_summary(archive)
    end

    desc 'Restore the admissions tables from a backup file into empty ones: FILE=path ' \
         '(ERASE_CURRENT_ADMISSIONS_DATA=yes erases the current admissions data first)'
    task restore: :environment do
      erase = ENV[Admissions::Backup::Restore::ERASE_FLAG] == 'yes'
      result = Admissions::Backup::Restore.new(File.binread(backup_file), erase_existing: erase).run
      if result.erased_counts.any?
        puts 'Erased the admissions data that was here:'
        result.erased_counts.each { |table, n| puts "  #{table}: #{n}" }
      end
      puts "Restored #{backup_file}."
      puts backup_summary(result.archive, counts: result.row_counts)
      puts "Staff users matched by email: #{result.users_matched}."
      if result.inconsistent.empty?
        puts 'The state rebuilder agrees with every applicant.'
      else
        puts "The state rebuilder disagrees with applicants #{result.inconsistent.join(', ')}, as it did in the file."
      end
    rescue Admissions::Backup::Restore::Refused => e
      abort "Nothing restored: #{e.message}."
    end

    def backup_file
      ENV['FILE'].presence || abort('Name the backup file: FILE=path')
    end

    # Rows per table, from the database when given, else from the file.
    def backup_summary(archive, counts: archive.row_counts)
      lines = ["Taken #{archive.taken_at.in_time_zone.strftime('%-d %B %Y at %H:%M')} (London time), " \
               "schema version #{archive.schema_version}.",
               "Checksum #{archive.checksum}; content #{archive.content_checksum}.",
               'Rows:']
      lines + counts.map { |table, n| "  #{table}: #{n}" }
    end
  end
end
