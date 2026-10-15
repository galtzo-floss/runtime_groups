# frozen_string_literal: true

require "anonymous_loader"
require "runtime_groups"
RSpec.describe RuntimeGroups::Version do
  it_behaves_like "a Version module", described_class

  it "executes the version file for coverage without redefining constants" do
    paths = [
      File.expand_path("../../lib/runtime_groups/version.rb", __dir__),
      File.expand_path("../../lib/runtime_groups/version_gem.rb", __dir__)
    ].select { |path| File.file?(path) }
    anonymous_namespace = AnonymousLoader.load(files: paths)

    expect(anonymous_namespace::RuntimeGroups::Version::VERSION).to eq(described_class::VERSION)
  end
end
