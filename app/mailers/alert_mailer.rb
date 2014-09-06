class AlertMailer < ActionMailer::Base
  default from: "Shepherd<no-reply@shepherd.com>"

  def alert_email(alert, divergence, time)
    @metric = alert.metric
    @divergence = divergence
    @time = time
    subject = @metric.name
    alert.recipient_list.each do |recipient|
        mail(to: recipient, subject: subject)
    end
  end

  helper :maps
end
