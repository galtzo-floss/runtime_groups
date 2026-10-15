# frozen_string_literal: true

module RuntimeGroups
  # Options-file discovery for RSpec option passthrough, mirroring
  # `ParallelTests::RSpec::Runner.spec_opts` (identical in parallel_tests
  # 3.5.2 through 5.8.0). Exposed here as public API so runners no longer
  # need to reach into parallel_tests internals.
  module Options
    # Options files checked, in priority order.
    SPEC_OPTS_FILES = [".rspec_parallel", "spec/parallel_spec.opts", "spec/spec.opts"].freeze

    module_function

    # First existing options file, in priority order.
    #
    # @param files [Array<String>] candidate paths (defaults to
    #   {SPEC_OPTS_FILES})
    # @return [String, nil]
    def options_file(files = SPEC_OPTS_FILES)
      files.detect { |file| File.file?(file) }
    end

    # RSpec argument string selecting the options file.
    #
    # @param files [Array<String>] candidate paths (defaults to
    #   {SPEC_OPTS_FILES})
    # @return [String, nil] e.g. "-O .rspec_parallel", or nil when no
    #   options file exists
    def spec_opts(files = SPEC_OPTS_FILES)
      found = options_file(files)
      "-O #{found}" if found
    end
  end
end
