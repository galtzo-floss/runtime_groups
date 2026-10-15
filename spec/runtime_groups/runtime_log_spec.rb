# frozen_string_literal: true

RSpec.describe RuntimeGroups::RuntimeLog do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:log_path) { File.join(tmp_dir, "runtimes.log") }

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  describe ".read" do
    it "reads recorded runtimes" do
      File.write(log_path, "./spec/a_spec.rb:1.5\n./spec/b_spec.rb:20\n")
      expect(described_class.read(log_path)).to eql("./spec/a_spec.rb" => 1.5, "./spec/b_spec.rb" => 20.0)
    end

    it "returns empty for nil" do
      expect(described_class.read(nil)).to eql({})
    end

    it "returns empty for a missing file" do
      expect(described_class.read(File.join(tmp_dir, "nope.log"))).to eql({})
    end

    it "skips blank and malformed lines" do
      File.write(log_path, "\nbogus\n./spec/a_spec.rb:2.25\n./spec/c_spec.rb\n:12\n")
      expect(described_class.read(log_path)).to eql("./spec/a_spec.rb" => 2.25)
    end
  end

  describe "#log" do
    it "records a first runtime, creating parent directories" do
      nested = File.join(tmp_dir, "sub", "runtimes.log")
      log = described_class.new(nested)
      expect(log.log("./spec/a_spec.rb", 3.5)).to eql(3.5)
      expect(described_class.read(nested)).to eql("./spec/a_spec.rb" => 3.5)
    end

    it "keeps the minimum on merge" do
      log = described_class.new(log_path)
      log.log("./spec/a_spec.rb", 5.0)
      expect(log.log("./spec/a_spec.rb", 2.0)).to eql(2.0)
      expect(log.log("./spec/a_spec.rb", 9.0)).to eql(2.0)
      expect(described_class.read(log_path)).to eql("./spec/a_spec.rb" => 2.0)
    end

    it "writes one line per file in sorted order" do
      log = described_class.new(log_path)
      log.log("./spec/b_spec.rb", 2)
      log.log("./spec/a_spec.rb", 1)
      expect(File.readlines(log_path).map(&:strip)).to eql(
        [
          "./spec/a_spec.rb:1.0",
          "./spec/b_spec.rb:2.0"
        ]
      )
    end
  end
end
