class TimeUtils
  def self.get_cropped_time(time, period)
    if period == 'hour'
      Time.new(time.year, time.month, time.day, time.hour, 0, 0, 0).utc
    elsif period == 'day'
      Time.new(time.year, time.month, time.day, 0, 0, 0, 0).utc
    end
  end
end