require_relative '../../../test_helper'
require 'tumugi/plugin/target/google_cloud_storage_file'

class Tumugi::Plugin::GoogleCloudStorageFileTargetTest < Test::Unit::TestCase
  setup do
    @bucket = "tumugi-plugin-gcs"
    @prefix = "#{SecureRandom.hex(10)}"
    @target = Tumugi::Plugin::GoogleCloudStorageFileTarget.new(bucket: @bucket, key: "#{@prefix}/test.txt")
    @target.fs.put_string('test', "gs://#{@bucket}/#{@prefix}/readable.txt")
  end

  teardown do
    @target.fs.remove("gs://#{@bucket}/#{@prefix}/")
  end

  test "initialize" do
    assert_equal(@bucket, @target.bucket)
    assert_equal("#{@prefix}/test.txt", @target.key)
    assert_equal("gs://#{@bucket}/#{@prefix}/test.txt", @target.path)

  end

  test "to_s" do
    assert_equal("gs://#{@bucket}/#{@prefix}/test.txt", @target.path)
  end

  test "exist?" do
    readable_target = Tumugi::Plugin::GoogleCloudStorageFileTarget.new(bucket: @bucket, key: "#{@prefix}/readable.txt")
    assert_true(readable_target.exist?)
    assert_false(@target.exist?)
  end

  sub_test_case "open" do
    test "write and read" do
      @target.open("w") do |f|
        f.puts("test")
      end
      @target.open("r") do |f|
        assert_equal("test\n", f.read)
      end
    end

    test "raise error when mode is invalid" do
      assert_raise(Tumugi::TumugiError) do
        @target.open("z")
      end
    end
  end
end
