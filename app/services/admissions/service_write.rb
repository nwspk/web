module Admissions
  # The guarded transaction every admissions service writes in. Inside it,
  # and only inside it, admissions.service_write is on, which the model
  # validations and the database triggers on applicants and the outbox
  # require. A savepoint (requires_new) means a failed change rolls the
  # setting back with everything else; on success the setting goes back to
  # what it was, so one service can call another inside its own write.
  module ServiceWrite
    private

    def service_write
      ActiveRecord::Base.transaction(requires_new: true) do
        previous = ActiveRecord::Base.connection.select_value(
          "SELECT current_setting('admissions.service_write', true)"
        )
        allow_service_write('on')
        result = yield
        allow_service_write(previous == 'on' ? 'on' : 'off')
        result
      end
    end

    def allow_service_write(value)
      ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(["SELECT set_config('admissions.service_write', ?, true)", value])
      )
    end

    # Microsecond precision, as Postgres stores it, so cached columns and
    # event timestamps compare equal before and after a reload.
    def timestamp = Time.current.floor(6)
  end
end
