require_relative '../../../test_helper'

class Tumugi::Plugin::GCSFileTargetTest < Test::Unit::TestCase
  setup do
    @target = Tumugi::Plugin::GCSFileTarget.new
  end
end
