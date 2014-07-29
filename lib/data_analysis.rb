class DataAnalysis
  @@MIN_SAMPLE_ELEMENTS = 20
  @@BOOTSTRAPPING_ITERATIONS = 10

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
      slice_percentiles = get_bootstrapping_percentiles(slice)
      slice_gap = slice_percentiles['high'] - slice_percentiles['low']
      slice_compactness = (1.0 - slice_gap / control_gap) ** 10
      slice_percentiles.keys.each do |percentile|
        percentiles[percentile] += slice_percentiles[percentile] * slice_compactness
      end
      divider += slice_compactness
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
    divider = 1
    while data.size / divider >= @@MIN_SAMPLE_ELEMENTS
      sample = reversed_data.each_slice(divider).map{|slice| slice.last}
      samples.push(sample.reverse)
      divider += 1
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
      percentile10 = percentile50 = percentile90 = 0
      relative_freqs.each do |value, rel_freq|
        new_accum_freq = accum_freq + rel_freq
        if accum_freq < 0.10 && new_accum_freq >= 0.10
          percentile10 = value
        end
        if accum_freq < 0.5 && new_accum_freq >= 0.5
          percentile50 = value
        end
        if accum_freq < 0.90 && new_accum_freq >= 0.90
          percentile90 = value
        end
        accum_freq = new_accum_freq
      end
      [percentile10, percentile50, percentile90]
    end
    # get percentile means
    percentile10_accum = percentile50_accum = percentile90_accum = 0
    percentiles.each do |percentile|
      percentile10_accum += percentile[0]
      percentile50_accum += percentile[1]
      percentile90_accum += percentile[2]
    end
    percentile10_mean = percentile10_accum.to_f / percentiles.size
    percentile50_mean = percentile50_accum.to_f / percentiles.size
    percentile90_mean = percentile90_accum.to_f / percentiles.size
    {
      'low' => percentile10_mean,
      'median' => percentile50_mean,
      'high' => percentile90_mean,
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
    if analysis['value'] == analysis['median']
      0
    else
      deviation = analysis['value'].to_f - analysis['median']
      if analysis['value'] > analysis['median']
        deviation / (analysis['high'] - analysis['median'])
      else
        deviation / (analysis['median'] - analysis['low'])
      end
    end
  end
end
