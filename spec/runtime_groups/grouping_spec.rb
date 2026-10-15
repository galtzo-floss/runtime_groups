# frozen_string_literal: true

RSpec.describe RuntimeGroups::Grouping do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:log_path) { File.join(tmp_dir, "runtimes.log") }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  def make_file(name, bytes)
    path = File.join(tmp_dir, name)
    File.write(path, "x" * bytes)
    path
  end

  describe ".with_size" do
    context "with group_by: :found" do
      it "weights every file equally" do
        a = make_file("a_spec.rb", 1)
        b = make_file("b_spec.rb", 500)
        expect(described_class.with_size([a, b], group_by: :found)).to eql(a => 1.0, b => 1.0)
      end
    end

    context "with group_by: :filesize" do
      it "weights files by byte size" do
        small = make_file("small_spec.rb", 3)
        large = make_file("large_spec.rb", 90)
        expect(described_class.with_size([small, large], group_by: :filesize)).to eql(small => 3.0, large => 90.0)
      end
    end

    context "with group_by: :runtime" do
      it "weights files by recorded runtime" do
        file = make_file("timed_spec.rb", 5)
        File.write(log_path, "#{file}:7.5\n")
        expect(described_class.with_size([file], runtime_log: log_path)).to eql(file => 7.5)
      end

      it "fills unknown files with the average of known runtimes" do
        known = make_file("known_spec.rb", 1)
        unknown = make_file("unknown_spec.rb", 1)
        File.write(log_path, "#{known}:2.0\n#{unknown}:9.0\n")
        log = File.read(log_path).gsub("#{unknown}:9.0\n", "")
        File.write(log_path, log)
        expect(described_class.with_size([known, unknown], runtime_log: log_path)).to eql(known => 2.0, unknown => 2.0)
      end

      it "honors an explicit unknown_runtime over the average" do
        known = make_file("known_spec.rb", 1)
        unknown = make_file("unknown_spec.rb", 1)
        File.write(log_path, "#{known}:2.0\n")
        expect(
          described_class.with_size([known, unknown], runtime_log: log_path, unknown_runtime: 7.5)
        ).to eql(known => 2.0, unknown => 7.5)
      end

      it "honors unknown_runtime when nothing is known" do
        file = make_file("blind_spec.rb", 1)
        expect(
          described_class.with_size([file], runtime_log: File.join(tmp_dir, "nope.log"), unknown_runtime: 3.0)
        ).to eql(file => 3.0)
      end

      it "fills every file with 1.0 when the log knows nothing" do
        file = make_file("blind_spec.rb", 1)
        expect(described_class.with_size([file], runtime_log: File.join(tmp_dir, "nope.log"))).to eql(file => 1.0)
      end

      it "raises when too many files are missing from the log" do
        a = make_file("a_spec.rb", 1)
        b = make_file("b_spec.rb", 1)
        File.write(log_path, "#{a}:1.0\n")
        expect do
          described_class.with_size([a, b], runtime_log: log_path, allowed_missing: 0.0)
        end.to raise_error(RuntimeGroups::RuntimeLogTooSmallError, /sufficient data/)
      end

      it "allows the missing budget before raising" do
        a = make_file("a_spec.rb", 1)
        b = make_file("b_spec.rb", 1)
        File.write(log_path, "#{a}:1.0\n")
        weights = described_class.with_size([a, b], runtime_log: log_path, allowed_missing: 0.5)
        expect(weights).to eql(a => 1.0, b => 1.0)
      end
    end

    context "with an invalid mode" do
      it "raises" do
        expect { described_class.with_size([], group_by: :bogus) }.to raise_error(
          RuntimeGroups::Error, /invalid group-by mode/
        )
      end
    end
  end

  describe ".in_groups" do
    it "returns exactly num_groups arrays" do
      files = Array.new(5) { |i| make_file("f#{i}_spec.rb", (i + 1) * 10) }
      groups = described_class.in_groups(files, 3, group_by: :filesize)
      expect(groups.length).to eql(3)
      expect(groups.flatten.length).to eql(5)
      expect(groups.flatten.sort).to eql(files.sort)
    end

    it "balances by weight, largest files first" do
      light = make_file("light_spec.rb", 10)
      heavy_a = make_file("heavy_a_spec.rb", 100)
      heavy_b = make_file("heavy_b_spec.rb", 100)
      groups = described_class.in_groups([heavy_a, heavy_b, light], 2, group_by: :filesize)
      sizes = groups.map { |group| group.sum { |f| File.stat(f).size } }
      expect(sizes.max - sizes.min).to be <= 10
      expect(groups.map(&:length).max).to eql(2)
    end

    it "balances by recorded runtime when a log is given" do
      slow = make_file("slow_spec.rb", 1)
      fast = make_file("fast_spec.rb", 1)
      medium = make_file("medium_spec.rb", 1)
      File.write(log_path, "#{slow}:100.0\n#{fast}:1.0\n#{medium}:2.0\n")
      groups = described_class.in_groups([slow, fast, medium], 2, runtime_log: log_path)
      slow_group = groups.find { |group| group.include?(slow) }
      expect(slow_group).to eql([slow])
    end

    it "allows empty groups when there are fewer files than groups" do
      file = make_file("only_spec.rb", 1)
      groups = described_class.in_groups([file], 3)
      expect(groups.map(&:empty?)).to eql([false, true, true])
    end

    it "is deterministic for identical input" do
      files = Array.new(6) { |i| make_file("d#{i}_spec.rb", (i + 2) * 5) }
      first = described_class.in_groups(files, 2, group_by: :filesize)
      expect(first).to eql(described_class.in_groups(files, 2, group_by: :filesize))
    end

    it "raises on a zero group count" do
      expect { described_class.in_groups([], 0) }.to raise_error(RuntimeGroups::Error, /positive integer/)
    end

    it "accepts a numeric String group count" do
      file = make_file("str_spec.rb", 1)
      groups = described_class.in_groups([file], "1")
      expect(groups).to eql([[file]])
    end
  end

  describe ".validate_groups! (public via RuntimeGroups.parse_count!)" do
    it "raises on negatives" do
      expect { RuntimeGroups.parse_count!(-1) }.to raise_error(RuntimeGroups::Error, /positive integer/)
    end
  end
end
