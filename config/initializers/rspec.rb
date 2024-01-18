module RSpec
  module Rails
    module FixtureFileUploadSupport
      class RailsFixtureFileWrapper
        class << self
          attr_accessor :file_fixture_path
        end
      end
    end
  end
end