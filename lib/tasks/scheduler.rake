desc 'Check for due staff reminders and send them'
task remind_staff: :environment do
  ProcessStaffRemindersService.new.call
end
