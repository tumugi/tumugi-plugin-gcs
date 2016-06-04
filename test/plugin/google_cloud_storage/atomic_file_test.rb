require_relative '../../test_helper'
require 'tumugi/plugin/google_cloud_storage/atomic_file'
require 'tumugi/plugin/google_cloud_storage/file_system'

class Tumugi::Plugin::GoogleCloudStorage::AtomicFileTest < Test::Unit::TestCase
  setup do
    @fs = Tumugi::Plugin::GoogleCloudStorage::FileSystem.new(credential)
    @bucket = "tumugi-plugin-gcs"
    @prefix = "#{SecureRandom.hex(10)}"
  end

  teardown do
    @fs.remove("gs://#{@bucket}/#{@prefix}/")
  end

  test "after open and close file, file upload to Google Cloud Storage" do
    path = "gs://#{@bucket}/#{@prefix}/atomic_gcs_file_test.txt"
    @file = Tumugi::Plugin::GoogleCloudStorage::AtomicFile.new(path, @fs)
    @file.open do |f|
      f.puts 'test'
    end
    @fs.exist?(path)
    @fs.download(path) do |f|
      assert_equal("test\n", f.read)
    end
  end
end
