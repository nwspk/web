# db/schema.rb has no syntax for Postgres triggers, so a database loaded from
# it (every test run, a fresh dev setup) would silently lack the admissions
# guards. This writes each trigger on an admissions_ table, and its function,
# into schema.rb as raw SQL, read back from the database itself.
module SchemaDumperTriggers
  private

  def trailer(stream)
    rows = @connection.select_rows(<<~SQL)
      SELECT pg_get_functiondef(p.oid), pg_get_triggerdef(t.oid)
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_proc p ON p.oid = t.tgfoid
      WHERE NOT t.tgisinternal AND c.relname LIKE 'admissions\\_%'
      ORDER BY c.relname, t.tgname
    SQL
    statements = rows.map(&:first).uniq.map { |f| "#{f.strip};" } + rows.map { |r| "#{r.last};" }
    if statements.any?
      stream.puts
      stream.puts "  execute <<~'SQL'"
      statements.each { |sql| stream.puts sql.gsub(/^(?=.)/, '    '), '' }
      stream.puts '  SQL'
    end
    super
  end
end

ActiveSupport.on_load(:active_record_postgresqladapter) do
  ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(SchemaDumperTriggers)
end
