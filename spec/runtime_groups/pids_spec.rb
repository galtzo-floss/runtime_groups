# frozen_string_literal: true

RSpec.describe RuntimeGroups::Pids do
  let(:path) { File.join(tmp_dir, "pids_#{Process.pid}.txt") }
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  describe "#to_a" do
    it "is empty when the file does not exist" do
      expect(described_class.new(path).to_a).to be_empty
    end

    it "reads recorded pids sorted and deduplicated" do
      File.write(path, "30\n10\n30\n")
      expect(described_class.new(path).to_a).to eql([10, 30])
    end

    it "skips corrupt lines" do
      File.write(path, "10\nbogus\n\n20\n")
      expect(described_class.new(path).to_a).to eql([10, 20])
    end
  end

  describe "#add" do
    it "records a pid, creating the file" do
      pids = described_class.new(path)
      expect(pids.add(11)).to eql([11])
      expect(described_class.new(path).to_a).to eql([11])
    end

    it "merges with pids recorded by other instances" do
      described_class.new(path).add(11)
      described_class.new(path).add(22)
      expect(described_class.new(path).to_a).to eql([11, 22])
    end

    it "is idempotent" do
      pids = described_class.new(path)
      pids.add(11)
      expect(pids.add(11)).to eql([11])
    end

    it "creates the parent directory when missing" do
      nested = File.join(tmp_dir, "deep", "ledger.txt")
      described_class.new(nested).add(5)
      expect(described_class.new(nested).to_a).to eql([5])
    end
  end

  describe "#delete" do
    it "removes a recorded pid" do
      pids = described_class.new(path)
      pids.add(11)
      pids.add(22)
      expect(pids.delete(11)).to eql([22])
    end

    it "ignores unknown pids" do
      pids = described_class.new(path)
      expect(pids.delete(99)).to be_empty
    end
  end

  describe "#clear" do
    it "empties the ledger" do
      pids = described_class.new(path)
      pids.add(11)
      expect(pids.clear).to be_empty
      expect(described_class.new(path).to_a).to be_empty
    end
  end
end

RSpec.describe RuntimeGroups::PidFile do
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  describe ".path" do
    it "uses the temp dir by default and is process-unique" do
      allow(Dir).to receive(:tmpdir).and_return(tmp_dir)
      path = described_class.path
      expect(path).to start_with(tmp_dir)
      expect(path).to end_with("runtime_groups_pids_#{Process.pid}")
    end

    it "honors a custom dir" do
      expect(described_class.path(dir: tmp_dir)).to eq(File.join(tmp_dir, "runtime_groups_pids_#{Process.pid}"))
    end
  end

  describe ".with" do
    it "yields a fresh empty ledger and removes it afterwards" do
      yielded = nil
      result = described_class.with(dir: tmp_dir) do |path|
        yielded = path
        File.write(path, "42\n")
        :block_result
      end
      expect(result).to be(:block_result)
      expect(File).not_to exist(yielded)
    end

    it "truncates a pre-existing file" do
      stale = described_class.path(dir: tmp_dir)
      File.write(stale, "999\n")
      described_class.with(dir: tmp_dir) do |path|
        expect(path).to eq(stale)
        expect(File.read(path)).to eq("")
      end
    end

    it "removes the ledger even when the block raises" do
      yielded = nil
      expect do
        described_class.with(dir: tmp_dir) do |path|
          yielded = path
          raise "boom"
        end
      end.to raise_error("boom")
      expect(File).not_to exist(yielded)
    end
  end
end
