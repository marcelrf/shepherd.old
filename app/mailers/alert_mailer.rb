class AlertMailer < ActionMailer::Base
  default from: 'no-reply@shepherd.com'

  def alert_email(recipient, subject, messages)
    @messages = messages
    mail(to: recipient, subject: subject)
  end

  helper :maps
end
