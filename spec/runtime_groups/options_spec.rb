# frozen_string_literal: true

RSpec.describe RuntimeGroups::Options do
  let(:tmp_dir) { Dir.mktmpdir }

  around do |example|
    Dir.chdir(tmp_dir) { example.run }
  end

  after { FileUtils.remove_entry(tmp_dir) if File.directory?(tmp_dir) }

  describe ".options_file" do
    it "returns nil when no options file exists" do
      expect(described_class.options_file).to be_nil
    end

    it "prefers .rspec_parallel" do
      File.write(File.join(tmp_dir, "spec/parallel_spec.opts"), "--tag slow") if Dir.mkdir(File.join(tmp_dir, "spec"))
      File.write(File.join(tmp_dir, ".rspec_parallel"), "--tag fast")
      expect(described_class.options_file).to eq(".rspec_parallel")
    end

    it "falls through to spec/parallel_spec.opts" do
      Dir.mkdir(File.join(tmp_dir, "spec"))
      File.write(File.join(tmp_dir, "spec/parallel_spec.opts"), "--tag slow")
      expect(described_class.options_file).to eq("spec/parallel_spec.opts")
    end

    it "honors custom candidates" do
      File.write(File.join(tmp_dir, "custom.opts"), "--tag x")
      expect(described_class.options_file(["custom.opts", ".rspec_parallel"])).to eq("custom.opts")
    end
  end

  describe ".spec_opts" do
    it "returns nil when no options file exists" do
      expect(described_class.spec_opts).to be_nil
    end

    it "builds the -O argument for the first existing file" do
      File.write(File.join(tmp_dir, ".rspec_parallel"), "--tag fast")
      expect(described_class.spec_opts).to eq("-O .rspec_parallel")
    end
  end
end
