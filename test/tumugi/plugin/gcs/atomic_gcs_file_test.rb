require_relative '../../../test_helper'
require 'tumugi/plugin/gcs/atomic_gcs_file'
require 'tumugi/plugin/gcs/gcs_file_system'

class Tumugi::Plugin::GCS::AtomicGCSFileTest < Test::Unit::TestCase
  setup do
    @fs = Tumugi::Plugin::GCS::GCSFileSystem.new(credential)
    @bucket = "tumugi-plugin-gcs"
    @prefix = "#{SecureRandom.hex(10)}"
  end

  teardown do
    @fs.remove("gs://#{@bucket}/#{@prefix}/")
  end

  test "after open and close file, file upload to GCS" do
    path = "gs://#{@bucket}/#{@prefix}/atomic_gcs_file_test.txt"
    download_path = "tmp/#{@prefix}_atomic_gcs_file_test.txt"

    @file = Tumugi::Plugin::GCS::AtomicGCSFile.new(path, @fs)
    @file.open do |f|
      f.puts 'test'
    end
    @fs.exist?(path)
    @fs.download(path, download_path)
    assert_equal("test\n", File.read(download_path))
  end
end
