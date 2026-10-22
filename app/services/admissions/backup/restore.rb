module Admissions
  module Backup
    # Puts a backup file back (`bin/rails admissions:backup:restore FILE=…`):
    #
    # 1. checks the file: its checksum, its row counts, and that it was taken
    #    at this database's schema version;
    # 2. refuses unless every admissions table is empty, or the caller asked
    #    to erase what is there (ERASE_FLAG);
    # 3. matches each staff user in the file to a user here by email, and
    #    refuses, naming them, if any is missing;
    # 4. writes every row back, with its id, in one transaction: all of the
    #    file or nothing.
    #
    # The guards stay on while it writes. Inserting is all the append-only
    # tables allow, and applicants and the outbox take writes only with
    # admissions.service_write set, which the restore sets for its own
    # transaction, as the admissions services do. Only erasing, which no
    # guard allows, turns the guards off, for this transaction only.
    class Restore
      class Refused < Error; end

      # The scary flag: erase the admissions data that is there now, and
      # restore the file in its place.
      ERASE_FLAG = 'ERASE_CURRENT_ADMISSIONS_DATA'.freeze

      Result = Struct.new(:archive, :row_counts, :erased_counts, :users_matched, :inconsistent, keyword_init: true)

      def initialize(bytes, erase_existing: false, connection: ActiveRecord::Base.connection)
        @bytes = bytes
        @erase_existing = erase_existing
        @connection = connection
      end

      def run
        archive = read
        check_schema!(archive)
        conn.transaction do
          lock_tables
          erased = clear_or_refuse
          user_ids = match_users!(archive.users)
          allow_service_write('on')
          TABLES.each { |table| insert(table, remap(table, archive.tables.fetch(table), user_ids)) }
          allow_service_write('off')
          TABLES.each { |table| reset_sequence(table) }
          Result.new(archive: archive, row_counts: counts, erased_counts: erased, users_matched: user_ids.size,
                     inconsistent: StateRebuilder.inconsistent.map(&:id))
        end
      end

      private

      def conn = @connection

      def read
        Archive.read(@bytes)
      rescue Archive::Invalid => e
        raise Refused, e.message
      end

      def check_schema!(archive)
        here = Backup.schema_version(conn)
        unless archive.schema_version == here
          raise Refused, "the file was taken at schema version #{archive.schema_version}, and this database is at " \
                         "#{here}. Restore it with the code and database at #{archive.schema_version}, then migrate"
        end
        unless archive.tables.keys.sort == TABLES.sort
          raise Refused, "the file's tables (#{archive.tables.keys.sort.join(', ')}) " \
                         "aren't this site's admissions tables"
        end

        TABLES.each do |table|
          row = archive.tables[table].first
          next if row.nil? || row.keys.sort == conn.columns(table).map(&:name).sort

          raise Refused, "the file's #{table} columns don't match this database's"
        end
      end

      # Nothing else writes to the admissions tables while the restore does;
      # reading goes on.
      def lock_tables
        conn.execute("LOCK TABLE #{TABLES.map { |t| conn.quote_table_name(t) }.join(', ')} IN EXCLUSIVE MODE")
      end

      def counts
        TABLES.index_with { |table| conn.select_value("SELECT count(*) FROM #{conn.quote_table_name(table)}").to_i }
      end

      def clear_or_refuse
        present = counts.select { |_, n| n.positive? }
        return {} if present.empty?

        unless @erase_existing
          raise Refused, "the admissions tables aren't empty (#{present.map { |t, n| "#{t}: #{n}" }.join(', ')}). " \
                         "To erase them and restore the file in their place, run again with #{ERASE_FLAG}=yes"
        end

        # Each table after the ones that point to it; the guards are off for
        # this transaction only, and come back on with it.
        TABLES.reverse_each do |table|
          name = conn.quote_table_name(table)
          conn.execute("ALTER TABLE #{name} DISABLE TRIGGER USER")
          conn.execute("DELETE FROM #{name}")
          conn.execute("ALTER TABLE #{name} ENABLE TRIGGER USER")
        end
        present
      end

      # { id in the file => id here }, matched by email in any case.
      def match_users!(users)
        found = users.to_h do |user|
          [user['id'], User.where('lower(email) = ?', user['email'].to_s.downcase).pick(:id)]
        end
        missing = users.select { |user| found[user['id']].nil? }.map { |user| user['email'] }
        if missing.any?
          raise Refused, "#{missing.size == 1 ? 'this staff user has' : 'these staff users have'} no account on this " \
                         "site: #{missing.join(', ')}. Create the account first (any role), then run the restore again"
        end
        found
      end

      def remap(table, rows, user_ids)
        columns = Backup.user_columns(table, conn)
        return rows if columns.empty?

        rows.map do |row|
          columns.each_with_object(row.dup) { |column, out| out[column] = user_ids.fetch(out[column]) if out[column] }
        end
      end

      def insert(table, rows)
        return if rows.empty?

        name = conn.quote_table_name(table)
        conn.execute("INSERT INTO #{name} SELECT * FROM json_populate_recordset(NULL::#{name}, " \
                     "#{conn.quote(JSON.generate(rows))}::json)")
      end

      def reset_sequence(table)
        name = conn.quote_table_name(table)
        conn.execute("SELECT setval(pg_get_serial_sequence(#{conn.quote(table)}, 'id'), " \
                     "coalesce((SELECT max(id) FROM #{name}), 0) + 1, false)")
      end

      def allow_service_write(value)
        ActiveRecord::Base.uncached do
          conn.select_value(ActiveRecord::Base.sanitize_sql(
                              ["SELECT set_config('admissions.service_write', ?, true)", value]
                            ))
        end
      end
    end
  end
end
