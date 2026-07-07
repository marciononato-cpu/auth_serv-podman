class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('EMAIL_FROM', 'labonosp@gmail.com')
  layout 'mailer'
end
