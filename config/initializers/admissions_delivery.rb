# A production host set to record admissions email instead of sending it
# (a staging rehearsal) says so in its log at boot.
Rails.application.config.after_initialize { Admissions::Delivery.warn_if_recording }
