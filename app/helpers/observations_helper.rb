module ObservationsHelper
  def endurance(start_time, end_time)
    months, weeks, days, hours = 0, 0, 0, 0
    while start_time < end_time
      if start_time + 1.month <= end_time
        months += 1
        start_time += 1.month
      elsif start_time + 1.week <= end_time
        weeks += 1
        start_time += 1.week
      elsif start_time + 1.day <= end_time
        days += 1
        start_time += 1.day
      elsif start_time + 1.hour <= end_time
        hours += 1
        start_time += 1.hour
      else
        start_time = end_time
      end
    end
    endurance = []
    endurance.push(months.to_s + ' month' + (months > 1 ? 's' : '')) if months > 0
    endurance.push(weeks.to_s + ' week' + (weeks > 1 ? 's' : '')) if weeks > 0
    endurance.push(days.to_s + ' day' + (days > 1 ? 's' : '')) if days > 0
    endurance.push(hours.to_s + ' hour' + (hours > 1 ? 's' : '')) if hours > 0
    endurance_body = endurance[0...-1]
    endurance_last = endurance[-1]
    if endurance_body.count > 0
      endurance[0...-1].join(', ') + ' and ' + endurance[-1]
    else
      endurance[-1]
    end
  end
end
