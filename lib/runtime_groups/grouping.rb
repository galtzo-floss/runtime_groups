# frozen_string_literal: true

module RuntimeGroups
  # Raised when runtime grouping cannot proceed because the runtime log does
  # not cover enough of the given files (the `allowed_missing` budget).
  class RuntimeLogTooSmallError < Error; end

  # Balanced grouping of test files into worker groups.
  #
  # Mirrors the semantics of `parallel_tests` 3.5.2 through 5.8.0 (identical
  # across those versions for this surface): weights come from a {RuntimeLog}
  # when present, files missing from the log get the average of the known
  # runtimes (or 1.0 when nothing is known) once the `allowed_missing` budget
  # permits, and groups are balanced largest-smallest — every file, in
  # descending weight order, goes to the group with the smallest accumulated
  # weight. Tie-breaking by filename makes the split deterministic
  # (`parallel_tests` tie order is unspecified).
  module Grouping
    module_function

    # Compute a weight for every file.
    #
    # @param files [Array<String>] test file paths
    # @param group_by [:runtime, :filesize, :found]
    # @param runtime_log [String, nil] runtime log path (for :runtime)
    # @param allowed_missing [Float] fraction of files allowed to be missing
    #   from the runtime log before {RuntimeLogTooSmallError} is raised
    # @return [Hash{String => Float}] file => weight
    # @raise [RuntimeGroups::RuntimeLogTooSmallError] when too many files are
    #   missing from the runtime log
    def with_size(files, group_by: :runtime, runtime_log: nil, allowed_missing: 1.0)
      case group_by
      when :found
        files.each_with_object({}) { |file, memo| memo[file] = 1.0 }
      when :filesize
        files.each_with_object({}) { |file, memo| memo[file] = File.stat(file).size.to_f }
      when :runtime
        runtime_weights(files, runtime_log, allowed_missing)
      else
        raise Error, "invalid group-by mode #{group_by.inspect}; expected one of: runtime, filesize, found"
      end
    end

    # Split files into balanced groups.
    #
    # @param files [Array<String>] test file paths
    # @param num_groups [Integer] positive group count; groups may be empty
    #   when there are fewer files than groups
    # @param group_by [:runtime, :filesize, :found] weighting mode
    # @param runtime_log [String, nil] runtime log path (for :runtime)
    # @param allowed_missing [Float] fraction of files allowed to be missing
    #   from the runtime log
    # @return [Array<Array<String>>] exactly `num_groups` arrays of file paths
    # @raise [RuntimeGroups::Error] when num_groups or group_by is invalid
    def in_groups(files, num_groups, group_by: :runtime, runtime_log: nil, allowed_missing: 1.0)
      groups = Array.new(RuntimeGroups.parse_count!(num_groups)) { {weight: 0.0, files: []} }
      weights = with_size(files, group_by: group_by, runtime_log: runtime_log, allowed_missing: allowed_missing)

      files.sort_by { |file| [-weights[file], file] }.each do |file|
        target = groups.min_by { |group| group[:weight] }
        target[:weight] += weights[file]
        target[:files] << file
      end

      groups.map { |group| group[:files] }
    end

    # Runtime weights with the missing-file budget and average-fill semantics
    # retained from `parallel_tests`.
    #
    # @return [Hash{String => Float}]
    def runtime_weights(files, runtime_log, allowed_missing)
      budget = files.size * allowed_missing
      runtimes = RuntimeLog.read(runtime_log)
      known, unknown = [], []

      files.each do |file|
        if runtimes.key?(file)
          known << [file, runtimes[file]]
        else
          budget -= 1
          if budget.negative?
            raise RuntimeLogTooSmallError,
              "Runtime log file '#{runtime_log}' does not contain sufficient data to sort #{files.size} test files, please update or remove it."
          end
          unknown << file
        end
      end

      weights = known.each_with_object({}) { |(file, seconds), memo| memo[file] = seconds }
      fill = known.empty? ? 1.0 : known.map(&:last).sum / known.size
      unknown.each { |file| weights[file] = fill }
      weights
    end
  end
end
