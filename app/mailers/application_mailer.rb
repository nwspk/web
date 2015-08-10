class ApplicationMailer < ActionMailer::Base
  default from: "NWSPK <notifications@nwspk.com>", reply_to: "ed@nwspk.com"
  layout 'mailer'
end
