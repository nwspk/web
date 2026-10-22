module Admissions
  module Backup
    # Every admissions table's rows, and the staff users they point to, read
    # in one statement so they are one consistent moment. Postgres turns each
    # row into JSON itself (row_to_json), and Restore turns it back the same
    # way (json_populate_recordset), so timestamps keep their microseconds
    # and jsonb its structure.
    class Snapshot
      attr_reader :tables, :users, :schema_version, :taken_at

      def self.take(connection: ActiveRecord::Base.connection)
        missing = Backup.tables_in_database(connection) - TABLES
        if missing.any?
          raise Error, "#{missing.join(', ')} #{missing.one? ? 'is' : 'are'} not in Admissions::Backup::TABLES, " \
                       'so the backup would leave it out'
        end

        taken_at = Time.current
        json = connection.select_value("SELECT json_build_object(#{selects(connection)})")
        data = JSON.parse(json)
        new(tables: TABLES.index_with { |t| data.fetch(t) }, users: data.fetch('users'),
            schema_version: Backup.schema_version(connection), taken_at: taken_at)
      end

      def self.selects(connection)
        tables = TABLES.map do |table|
          name = connection.quote_table_name(table)
          "#{connection.quote(table)}, (SELECT coalesce(json_agg(r ORDER BY r.id), '[]'::json) FROM #{name} r)"
        end
        tables << "'users', (#{users_select(connection)})"
        tables.join(', ')
      end

      # Ids and emails only: nothing else about a user goes in the file.
      def self.users_select(connection)
        refs = TABLES.flat_map do |table|
          Backup.user_columns(table, connection).map do |column|
            "SELECT #{connection.quote_column_name(column)} FROM #{connection.quote_table_name(table)}"
          end
        end
        <<~SQL.squish
          SELECT coalesce(json_agg(json_build_object('id', u.id, 'email', u.email) ORDER BY u.id), '[]'::json)
          FROM users u WHERE u.id IN (#{refs.join(' UNION ')})
        SQL
      end
      private_class_method :selects, :users_select

      def initialize(tables:, users:, schema_version:, taken_at:)
        @tables = tables
        @users = users
        @schema_version = schema_version
        @taken_at = taken_at
      end

      def data = { 'tables' => tables, 'users' => users }
      def row_counts = tables.transform_values(&:size)

      # The checksum of everything but the backup log, which changes every
      # night: equal checksums mean nothing worth a new backup changed.
      def content_checksum
        @content_checksum ||= Backup.sha256(JSON.generate(tables.except(LOG_TABLE).merge('users' => users)))
      end

      # { round name => applicant count }, in the rounds' order.
      def applicants_per_round
        counts = tables['admissions_applicants'].group_by { |a| a['round_id'] }.transform_values(&:size)
        tables['admissions_rounds'].to_h { |round| [round['name'], counts.fetch(round['id'], 0)] }
      end
    end
  end
end
