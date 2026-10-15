# frozen_string_literal: true

require "fileutils"

module RuntimeGroups
  # Reader and writer for a runtime log: `path:seconds` per line, recording
  # how long each test file took in a previous run. The log is what makes
  # {Grouping} balance groups by measured runtime instead of file size.
  #
  # The writer merges with the minimum: a recorded runtime only gets slower
  # in the log when a subsequent run of that file is actually slower, so one
  # slow run (GC pause, cold cache) does not permanently poison the balance.
  class RuntimeLog
    # Read a runtime log.
    #
    # @param path [String, nil] log file path; nil or a missing file reads as
    #   an empty hash
    # @return [Hash{String => Float}] file path => recorded seconds
    def self.read(path)
      return {} if path.nil? || !File.file?(path)

      File.readlines(path).each_with_object({}) do |line, memo|
        file, seconds = line.strip.split(":", 2)
        next if file.nil? || file.empty? || seconds.nil? || seconds.empty?

        begin
          memo[file] = Float(seconds)
        rescue ArgumentError
          next
        end
      end
    end

    # @param path [String] log file path
    def initialize(path)
      @path = path
    end

    # Record a runtime for a file, merged as the minimum of the recorded and
    # given values. Creates the file (and its parent directory) on first use.
    #
    # @param file [String] test file path (the key later read back)
    # @param seconds [Numeric]
    # @return [Float] the recorded value after the merge
    def log(file, seconds)
      current = self.class.read(@path)
      merged = current.key?(file) ? [current[file], seconds.to_f].min : seconds.to_f
      current[file] = merged
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, "w") do |f|
        current.keys.sort.each { |key| f.puts("#{key}:#{current[key]}") }
      end
      merged
    end
  end
end
