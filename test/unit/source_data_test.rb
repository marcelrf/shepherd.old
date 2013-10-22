class SourceDataTest < ActiveSupport::TestCase
  setup :setup

  def setup
    RSpec::Mocks.setup(self)
  end

  test "get source data" do
    metric = Metric.new(:source_info => '{"name":"source_1"}')
    start = Time.new(2013, 1, 1, 0, 0, 0, 0).utc
    period = 'day'
    SourceData.stub(:get_source_data_from_source_1).with(metric, start, period) {
      'source_data_1'
    }
    source_data = SourceData.get_source_data(metric, start, period)
    assert source_data == 'source_data_1'
  end
end
