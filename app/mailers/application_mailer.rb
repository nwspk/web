class ApplicationMailer < ActionMailer::Base
  default from: 'NWSPK <notifications@nwspk.com>', reply_to: 'ed@newspeak.house'
  layout 'mailer'
end
