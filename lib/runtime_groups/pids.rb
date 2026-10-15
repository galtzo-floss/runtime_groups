# frozen_string_literal: true

require "fileutils"

module RuntimeGroups
  # A file-backed ledger of live worker pids.
  #
  # Unlike the pid bookkeeping in `parallel_tests` (whose `Pids` instances do
  # not read before writing, so every fresh instance overwrites the file with
  # an empty in-memory list), every mutation here re-reads the file first and
  # writes the merged set. The file can therefore be shared safely between
  # the parent process and any number of tracking call sites.
  class Pids
    attr_reader :path

    # @param path [String] file path backing the ledger
    def initialize(path)
      @path = path
    end

    # @return [Array<Integer>] the pids currently recorded, deduplicated and
    #   sorted ascending; empty when the file does not exist yet
    def to_a
      return [] unless File.file?(@path)

      File.readlines(@path).map do |line|
        Integer(line.strip, 10)
      rescue ArgumentError
        nil
      end.compact.uniq.sort
    end

    # Record a pid. Idempotent.
    #
    # @param pid [Integer]
    # @return [Array<Integer>] the recorded pids after the add
    def add(pid)
      current = to_a
      return current if current.include?(pid)

      write(current + [pid])
    end

    # Remove a pid. Missing pids are ignored.
    #
    # @param pid [Integer]
    # @return [Array<Integer>] the recorded pids after the delete
    def delete(pid)
      write(to_a - [pid])
    end

    # Remove every recorded pid.
    #
    # @return [Array<Integer>] always empty
    def clear
      write([])
    end

    private

    def write(pids)
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, "w") do |f|
        pids.uniq.sort.each { |pid| f.puts(pid) }
      end
      pids
    end
  end

  # Scoped management of a pid ledger file for the duration of a parallel
  # fan-out.
  module PidFile
    module_function

    # Default ledger path, unique per process.
    #
    # @param dir [String, nil] directory for the file (default: Dir.tmpdir)
    # @return [String]
    def path(dir: nil)
      require "tmpdir"
      File.join(dir || Dir.tmpdir, "runtime_groups_pids_#{Process.pid}")
    end

    # Create (or truncate) a pid ledger file, yield its path for worker
    # spawning, then always remove the file.
    #
    # @param dir [String, nil] directory for the file (default: Dir.tmpdir)
    # @yieldparam path [String] the ledger path to hand to {Pids}
    # @return [Object] the block's return value
    def with(dir: nil)
      path = path(dir: dir)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "")
      yield path
    ensure
      File.delete(path) if File.exist?(path)
    end
  end
end
