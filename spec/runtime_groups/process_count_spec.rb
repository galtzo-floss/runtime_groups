# frozen_string_literal: true

RSpec.describe RuntimeGroups do
  describe ".process_count" do
    context "with an explicit count" do
      it "accepts a positive Integer" do
        expect(RuntimeGroups.process_count(4)).to eql(4)
      end

      it "accepts a numeric String" do
        expect(RuntimeGroups.process_count("3")).to eql(3)
      end

      it "rejects zero and negatives" do
        expect { RuntimeGroups.process_count(0) }.to raise_error(RuntimeGroups::Error, /positive integer/)
        expect { RuntimeGroups.process_count(-2) }.to raise_error(RuntimeGroups::Error, /positive integer/)
      end

      it "rejects non-numeric values" do
        expect { RuntimeGroups.process_count("four") }.to raise_error(RuntimeGroups::Error, /positive integer/)
      end

      it "takes precedence over the environment" do
        expect(RuntimeGroups.process_count(2, env: { "PARALLEL_TEST_PROCESSORS" => "9" })).to eql(2)
      end
    end

    context "without an explicit count" do
      it "reads the environment variable" do
        expect(RuntimeGroups.process_count(env: { "PARALLEL_TEST_PROCESSORS" => "5" })).to eql(5)
      end

      it "ignores a blank environment variable" do
        allow(Etc).to receive(:nprocessors).and_return(7)
        expect(RuntimeGroups.process_count(env: { "PARALLEL_TEST_PROCESSORS" => "  " })).to eql(7)
      end

      it "rejects a non-numeric environment variable" do
        expect do
          RuntimeGroups.process_count(env: { "PARALLEL_TEST_PROCESSORS" => "many" })
        end.to raise_error(RuntimeGroups::Error, /positive integer/)
      end

      it "falls back to the machine core count" do
        allow(Etc).to receive(:nprocessors).and_return(6)
        expect(RuntimeGroups.process_count(env: {})).to eql(6)
      end

      it "honors a custom env key" do
        expect(RuntimeGroups.process_count(env: { "MY_WORKERS" => "8" }, env_key: "MY_WORKERS")).to eql(8)
      end
    end
  end

  describe ".parse_count!" do
    it "passes through positive integers" do
      expect(RuntimeGroups.parse_count!(1)).to eql(1)
    end

    it "raises on zero" do
      expect { RuntimeGroups.parse_count!(0) }.to raise_error(RuntimeGroups::Error, /0/)
    end
  end
end
