class ApplicationMailer < ActionMailer::Base
  default from: "NWSPK <notifications@nwspk.com>", return_path: "ed@nwspk.com"
  layout 'mailer'
end
