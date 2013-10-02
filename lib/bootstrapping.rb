module Bootstrapping
  # def get_bootstrapping_analysis(values)
  #   ###
  # end

  # def get_bootstrapping_percentiles(values)
  #   samples = get_bootstrapping_samples(values, 1000)
  #   # transform samples into percentiles
  #   percentiles = samples.map do |sample|
  #     freqs = Hash.new{|h, k| h[k] = 0}
  #     sample.each do |value|
  #       freqs[value] += 1
  #     end
  #     relative_freqs = freqs.keys.sort.map do |value|
  #       [value, freqs[value].to_f / sample.size]
  #     end
  #     accum_freq = 0
  #     percentile05 = percentile50 = percentile95 = 0
  #     relative_freqs.each do |value, rel_freq|
  #       new_accum_freq = accum_freq + rel_freq
  #       if accum_freq < 0.05 && new_accum_freq >= 0.05
  #         percentile05 = value
  #       elsif accum_freq < 0.5 && new_accum_freq >= 0.5
  #         percentile50 = value
  #       elsif accum_freq < 0.95 && new_accum_freq >= 0.95
  #         percentile95 = value
  #       end
  #       accum_freq = new_accum_freq
  #     end
  #     [percentile05, percentile50, percentile95]
  #   end
  #   # get percentile means
  #   percentile05_accum = percentile50_accum = percentile95_accum = 0
  #   percentiles.each do |percentile|
  #     percentile05_accum += percentile[0]
  #     percentile50_accum += percentile[1]
  #     percentile95_accum += percentile[2]
  #   end
  #   percentile05_mean = percentile05_accum.to_f / percentiles.size
  #   percentile50_mean = percentile50_accum.to_f / percentiles.size
  #   percentile95_mean = percentile95_accum.to_f / percentiles.size
  #   {
  #     'low' => percentile05_mean,
  #     'median' => percentile50_mean,
  #     'high' => percentile95_mean,
  #   }
  # end

  # def get_bootstrapping_samples(values, iterations)
  #   # give weight to values depending on how recent they are
  #   # using a magic number algorithm
  #   weighted_values = []
  #   counter, magic_number = 1, 1
  #   while magic_number <= values.count
  #     (1..magic_number).each do |index|
  #       weighted_values.push(values[-index])
  #     end
  #     counter += 1
  #     magic_number += counter
  #   end
  #   weighted_values.concat(values)
  #   # create the samples
  #   samples = []
  #   iterations.times do
  #     sample = []
  #     values.size.times do
  #       sample.push(weighted_values[(rand * weighted_values.size).to_i])
  #     end
  #     samples.push(sample)
  #   end
  #   samples
  # end
end
