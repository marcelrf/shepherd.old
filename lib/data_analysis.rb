class DataAnalysis
  @@BOOTSTRAPPING_ITERATIONS = 100
  @@MIN_SAMPLE_SIZE = 10

  def self.get_data_analysis(data)
    control_data, current_data = data[0...-1], data[-1]
    control_gap = control_data.max - control_data.min
    if control_gap == 0
      return get_flat_percentiles(control_data.first, current_data)
    end
    slices = get_data_slices(control_data)
    percentiles = Hash.new{|h, k| h[k] = 0}
    divider = 0
    slices.each_with_index do |slice, index|
      next if slice.size < @@MIN_SAMPLE_SIZE
      slice_percentiles = get_bootstrapping_percentiles(slice)
      slice_gap = slice_percentiles['high'] - slice_percentiles['low']
      slice_compactness = (1.0 - slice_gap / control_gap)
      slice_trust = get_slice_trust(slice.size)
      slice_factor = (slice_compactness * slice_trust) ** 10
      # print "#{slice_factor} #{slice_compactness} #{slice_trust} #{index} #{slice_percentiles}\n"
      slice_percentiles.keys.each do |percentile|
        percentiles[percentile] += slice_percentiles[percentile] * slice_factor
      end
      divider += slice_factor
    end
    percentiles.keys.each do |percentile|
      percentiles[percentile] /= divider
    end
    percentiles['value'] = current_data
    percentiles
  end

  def self.get_flat_percentiles(value, current)
    {
      'low' => value,
      'median' => value,
      'high' => value,
      'value' => current,
    }
  end

  def self.get_data_slices(data)
    reversed_data = data.reverse
    samples = []
    dividers = [1, 24, 168] # TODO: add new slices when using other periods than hour!
    while dividers.size > 0
      divider = dividers.shift
      sample = reversed_data.each_slice(divider).map{|slice| slice.last}
      samples.push(sample.reverse)
    end
    samples
  end

  def self.get_bootstrapping_percentiles(values)
    samples = get_bootstrapping_samples(values, @@BOOTSTRAPPING_ITERATIONS)
    # transform samples into percentiles
    percentiles = samples.map do |sample|
      freqs = Hash.new{|h, k| h[k] = 0}
      sample.each do |value|
        freqs[value] += 1
      end
      relative_freqs = freqs.keys.sort.map do |value|
        [value, freqs[value].to_f / sample.size]
      end
      accum_freq = 0
      percentile_low = percentile_median = percentile_high = 0
      relative_freqs.each do |value, rel_freq|
        new_accum_freq = accum_freq + rel_freq
        if accum_freq < 0.1 && new_accum_freq >= 0.1
          percentile_low = value
        end
        if accum_freq < 0.5 && new_accum_freq >= 0.5
          percentile_median = value
        end
        if accum_freq < 0.9 && new_accum_freq >= 0.9
          percentile_high = value
        end
        accum_freq = new_accum_freq
      end
      [percentile_low, percentile_median, percentile_high]
    end
    # get percentile means
    percentile_low_accum = percentile_median_accum = percentile_high_accum = 0
    percentiles.each do |percentile|
      percentile_low_accum += percentile[0]
      percentile_median_accum += percentile[1]
      percentile_high_accum += percentile[2]
    end
    percentile_low_mean = percentile_low_accum.to_f / percentiles.size
    percentile_median_mean = percentile_median_accum.to_f / percentiles.size
    percentile_high_mean = percentile_high_accum.to_f / percentiles.size
    {
      'low' => percentile_low_mean,
      'median' => percentile_median_mean,
      'high' => percentile_high_mean,
    }
  end

  def self.get_bootstrapping_samples(values, iterations)
    samples = []
    iterations.times do
      sample = []
      values.size.times do
        # multiply random float between 0 an 1 by 0.3
        # to give more weight to recent values
        sample.push(values[((rand ** 0.3) * values.size).to_i])
      end
      samples.push(sample)
    end
    samples
  end

  def self.get_divergence(analysis)
    m, v = analysis['median'], analysis['value']
    return 0 if m == 0
    if v >= m
      h = analysis['high']
      return 0 if h == 0
      Math.log(v / h) / Math.log(h / m) + 1
    else
      l = analysis['low']
      return 0 if l == 0
      -(Math.log(v / l) / Math.log(l / m) + 1)
    end
  end

  def self.get_slice_trust(size)
    enclosed_size = [size, 30].min
    (Math.cos((((enclosed_size / 30.to_f) ** 2) - 1) * Math::PI) + 1) / 2
  end
end
