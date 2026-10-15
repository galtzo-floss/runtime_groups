# frozen_string_literal: true

require "etc"
require "version_gem"
require_relative "runtime_groups/version"

module RuntimeGroups
  class Error < StandardError; end

  # Environment variable checked for a default worker process count, kept
  # identical to the `parallel_tests` convention so an existing CI
  # configuration keeps working when a runner switches to this gem.
  DEFAULT_PROC_COUNT_ENV = "PARALLEL_TEST_PROCESSORS"

  module_function

  # Resolve the worker process count for a parallel run.
  #
  # Resolution order:
  # 1. An explicit `count` argument (must be a positive Integer, or a String
  #    parseable as one).
  # 2. `ENV[env_key]` (defaults to "PARALLEL_TEST_PROCESSORS"); blank values
  #    are ignored.
  # 3. `Etc.nprocessors` — the machine's core count. Works on every engine
  #    (MRI, JRuby, TruffleRuby): JRuby reports the JVM's available
  #    processors.
  #
  # The caller is responsible for resource budgeting: on JVM engines each
  # worker is a full JVM whose default heap can be 1/4 of machine RAM, so
  # the core-count default can exhaust a constrained runner. Cap it
  # explicitly there (see turbo_tests2's resource-constrained CI docs).
  #
  # @param count [Integer, String, nil]
  # @param env [Hash] environment mapping (defaults to ENV)
  # @param env_key [String]
  # @return [Integer] positive worker count
  # @raise [RuntimeGroups::Error] when an explicit count or env value is not
  #   a positive integer
  def process_count(count = nil, env: ENV, env_key: DEFAULT_PROC_COUNT_ENV)
    return parse_count!(count) unless count.nil?

    from_env = env[env_key]
    return parse_count!(from_env) unless from_env.nil? || from_env.strip.empty?

    Etc.nprocessors
  end

  # Parse and validate a worker count value.
  #
  # @param value [Integer, String]
  # @return [Integer] positive worker count
  # @raise [RuntimeGroups::Error] when the value is not a positive integer
  def parse_count!(value)
    count = value.is_a?(Integer) ? value : Integer(value, 10)
    return count if count.positive?

    raise Error, "invalid worker count #{value.inspect}; expected a positive integer"
  rescue ArgumentError
    raise Error, "invalid worker count #{value.inspect}; expected a positive integer"
  end
end

require_relative "runtime_groups/pids"
require_relative "runtime_groups/runtime_log"
require_relative "runtime_groups/options"
require_relative "runtime_groups/grouping"

RuntimeGroups::Version.class_eval do
  extend VersionGem::Basic
end
