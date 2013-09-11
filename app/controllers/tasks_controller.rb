class TasksController < ApplicationController
  include SourceData
  include Bootstrapping

  @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'

  def analyze_metric
    metric = Metric.find(params['id'])
    source_info = JSON.parse(metric.source_info)
    check_start = Time.strptime(params['start'], '%Y-%m-%dT%H:%M:%S')
    check_end = Time.strptime(params['end'], '%Y-%m-%dT%H:%M:%S')

    granularity = get_check_granularity(check_start, check_end)
    control_periods = get_control_periods(granularity, metric.seasonalities)
    start_time, end_time = get_date_range(check_start, check_end, control_periods[-1])
    source_data = get_source_data(source_info, start_time, end_time, granularity)
    control_data, current_data = source_data[0...-1], source_data[-1]

    bootstrapping_results = {}
    control_periods.each do |control_period|
      period_data = get_sliced_data(control_data, control_period, granularity)
      period_values = period_data.map{|element| element['y']}
      period_percentiles = get_bootstrapping_percentiles(period_values)
      bootstrapping_results[control_period] = period_percentiles
    end

    accumulated_low, accumulated_median, accumulated_high = 0, 0, 0
    bootstrapping_results.each do |period, percentiles|
      accumulated_low += percentiles['low']
      accumulated_median += percentiles['median']
      accumulated_high += percentiles['high']
    end
    total_low = accumulated_low / bootstrapping_results.count
    total_median = accumulated_median / bootstrapping_results.count
    total_high = accumulated_high / bootstrapping_results.count

    difference = current_data['y'] - total_median
    if difference > 0
      divergence = difference / (total_high - total_median)
    elsif difference < 0 
      divergence = -difference / (total_low - total_median)
    else
      divergence = 0
    end

    render :json => {
      'low' => total_low,
      'median' => total_median,
      'high' => total_high,
      'value' => current_data['y'],
      'divergence' => divergence,
      'data' => source_data[-[30, source_data.size].min..-1],
    }
  end

  private

  def get_check_granularity(check_start, check_end)
    time_delta = check_end - check_start
    if time_delta == 1.hour && check_start.min == 0 && check_start.sec == 0
      'hour'
    elsif (time_delta == 1.day && check_start.hour == 0 &&
           check_start.min == 0 && check_start.sec == 0)
      'day'
    elsif (time_delta == 1.week && check_start.wday == 1 &&
           check_start.hour == 0 && check_start.min == 0 && check_start.sec == 0)
      'week'
    elsif ((check_end.month - check_start.month == 1 || check_start.month == 12 && check_end.month == 1) &&
           check_start.day == 1 && check_start.hour == 0 && check_start.min == 0 && check_start.sec == 0 &&
           check_end.day == 1 && check_end.hour == 0 && check_end.min == 0 && check_end.sec == 0)
      'month'
    else
      nil
    end
  end

  def get_control_periods(granularity, seasonalities)
    periods = ['hour', 'day', 'week', 'month']
    control_periods = []
    granularity_index = periods.index(granularity)
    granularity_next_period = periods[granularity_index + 1]
    [granularity, granularity_next_period]
    # if seasonalities.include?(granularity_next_period)
    #   control_periods.push(granularity_next_period)
    # else
    #   control_periods.push(granularity)
    # end
    # granularity_second_next_period = periods[granularity_index + 2]
    # if seasonalities.include?(granularity_second_next_period)
    #   control_periods.push(granularity_second_next_period)
    # end
    # control_periods
  end

  def get_date_range(check_start, check_end, largest_control_period)
    if largest_control_period == 'hour'
      [check_start - 24.hours, check_end]
    elsif largest_control_period == 'day'
      [check_start - 30.days, check_end]
    elsif largest_control_period == 'week'
      [check_start - 26.weeks, check_end]
    elsif largest_control_period == 'month'
      [check_start - 12.months, check_end]
    end
  end

  def get_sliced_data(control_data, control_period, granularity)
    if granularity == 'hour'
      if control_period == 'hour'
        control_data[-[24, control_data.size].min..-1]
      elsif control_period == 'day'
        slices = control_data.each_slice(24)
        slices.map{|slice| slice[0]}[-[30, slices.size].min..-1]
      elsif control_period == 'week'
        slices = control_data.each_slice(168)
        slices.map{|slice| slice[0]}[-[26, slices.size].min..-1]
      end
    elsif granularity == 'day'
      if control_period == 'day'
        control_data[-[30, control_data.size].min..-1]
      elsif control_period == 'week'
        slices = control_data.each_slice(7)
        slices.map{|slice| slice[0]}[-[26, slices.size].min..-1]
      elsif control_period == 'month'
        initial_day = Time.strptime(control_data[0]['x'], @@TIME_FORMAT)
        last_day = Time.strptime(control_data[-1]['x'], @@TIME_FORMAT)
        current_day = initial_day
        sum_counter = 0
        sliced_data = []
        while current_day < last_day
          current_element = control_data.select do |element|
            Time.strptime(element['x'], @@TIME_FORMAT) == current_day
          end
          sliced_data.push(current_element[0])
          sum_counter += 1
          current_day = initial_day + sum_counter.months
        end
        sliced_data[-[12, sliced_data.size].min..-1]
      end
    elsif granularity == 'week'
      if control_period == 'week'
        control_data[-[26, control_data.size].min..-1]
      elsif control_period == 'month'
        nil #TODO! pick the most centered week
      end
    elsif granularity == 'months'
      control_data[-[12, control_data.size].min..-1]
    end
  end

end
