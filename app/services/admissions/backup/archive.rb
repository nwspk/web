require 'zlib'

module Admissions
  module Backup
    # The backup file: gzipped JSON Lines with two lines.
    #
    # 1. The header: the format, the schema version (the database's latest
    #    migration), when it was taken, the row count of each table, the
    #    content checksum the nightly run compares, and the checksum of the
    #    data line, exactly as written.
    # 2. The data: { "tables" => { table => [row, ...] }, "users" => [{ id,
    #    email }] }.
    #
    # The checksum covers the data line's bytes as written, so checking it
    # never depends on how JSON is re-encoded.
    class Archive
      class Invalid < Error; end

      FORMAT = 'nwspk-admissions-backup'.freeze
      FORMAT_VERSION = 1
      CONTENT_TYPE = 'application/gzip'.freeze

      attr_reader :header, :data, :bytes

      def self.build(snapshot)
        data_line = JSON.generate(snapshot.data)
        header = {
          'format' => FORMAT,
          'format_version' => FORMAT_VERSION,
          'schema_version' => snapshot.schema_version,
          'taken_at' => snapshot.taken_at.utc.iso8601(6),
          'row_counts' => snapshot.row_counts,
          'content_checksum' => snapshot.content_checksum,
          'checksum' => Backup.sha256(data_line),
          'restore' => 'bin/rails admissions:backup:restore FILE=<this file>'
        }
        new(header: header, data: snapshot.data, bytes: gzip("#{JSON.generate(header)}\n#{data_line}\n"))
      end

      # Reads and checks a file: refuses anything that isn't a whole,
      # unchanged admissions backup in a format this code reads.
      def self.read(bytes)
        text = gunzip(bytes)
        header_line, data_line = text.split("\n", 2)
        header = parse(header_line, 'its header')
        unless header.is_a?(Hash) && header['format'] == FORMAT
          raise Invalid, "this isn't an admissions backup file (its header doesn't say #{FORMAT})"
        end
        unless header['format_version'] == FORMAT_VERSION
          raise Invalid, "the file is in backup format #{header['format_version'].inspect}, " \
                         "and this site reads format #{FORMAT_VERSION}"
        end

        data_line = data_line.to_s.chomp("\n")
        unless Backup.sha256(data_line) == header['checksum']
          raise Invalid, "the checksum doesn't match: the file is damaged or has been changed"
        end

        data = parse(data_line, 'its data')
        counts = data.fetch('tables', {}).transform_values(&:size)
        unless counts == header['row_counts']
          raise Invalid, "the row counts in the header don't match the rows in the file"
        end

        new(header: header, data: data, bytes: bytes)
      end

      def initialize(header:, data:, bytes:)
        @header = header
        @data = data
        @bytes = bytes
      end

      def tables = data.fetch('tables')
      def users = data.fetch('users')
      def schema_version = header['schema_version']
      def taken_at = Time.iso8601(header['taken_at'])
      def row_counts = header['row_counts']
      def checksum = header['checksum']
      def content_checksum = header['content_checksum']

      def filename = "admissions-backup-#{taken_at.utc.strftime('%Y-%m-%dT%H%MZ')}.jsonl.gz"

      def self.gzip(text)
        io = StringIO.new(+'', 'wb')
        gz = Zlib::GzipWriter.new(io, Zlib::BEST_COMPRESSION)
        gz.write(text)
        gz.close
        io.string
      end

      def self.gunzip(bytes)
        Zlib::GzipReader.new(StringIO.new(bytes)).read.force_encoding('UTF-8')
      rescue Zlib::Error
        raise Invalid, "this isn't an admissions backup file (it isn't gzipped)"
      end

      def self.parse(line, what)
        JSON.parse(line.to_s)
      rescue JSON::ParserError
        raise Invalid, "this isn't an admissions backup file (#{what} can't be read)"
      end
      private_class_method :gzip, :gunzip, :parse
    end
  end
end
