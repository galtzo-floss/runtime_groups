# frozen_string_literal: true

RSpec.describe RuntimeGroups do
  it "has a version number" do
    expect(RuntimeGroups::VERSION).not_to be_nil
  end

  it "exposes the documented API surface" do
    expect(described_class).to respond_to(:process_count)
    expect(described_class).to respond_to(:parse_count!)
    expect(described_class::PidFile).to respond_to(:with)
    expect(described_class::RuntimeLog).to respond_to(:read)
    expect(described_class::Options).to respond_to(:spec_opts)
    expect(described_class::Grouping).to respond_to(:in_groups)
  end

  it "keeps errors under the gem namespace" do
    expect(described_class::Error).to be < StandardError
    expect(described_class::RuntimeLogTooSmallError).to be < described_class::Error
  end

  it "resolves a count end-to-end with the default environment key" do
    stub_const("ENV", { "PARALLEL_TEST_PROCESSORS" => "4" })
    expect(described_class.process_count).to eql(4)
  end
end
