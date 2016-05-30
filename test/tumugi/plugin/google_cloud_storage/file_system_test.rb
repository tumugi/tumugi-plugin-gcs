require_relative '../../../test_helper'
require 'tumugi/plugin/google_cloud_storage/file_system'

class Tumugi::Plugin::GoogleCloudStorage::FileSystemTest < Test::Unit::TestCase
  setup do
    @fs = Tumugi::Plugin::GoogleCloudStorage::FileSystem.new(credential)
    @bucket = "tumugi-plugin-gcs"
    @prefix = "#{SecureRandom.hex(10)}"
    @keys = [ "file1.txt", "folder/file2.txt"]
    @keys.each do |key|
      @fs.put_string('test', "gs://#{@bucket}/#{@prefix}/fs_test/#{key}")
    end
  end

  teardown do
    @fs.remove("gs://#{@bucket}/#{@prefix}/")
  end

  sub_test_case "exist?" do
    test "true" do
      assert_true(@fs.exist?("gs://#{@bucket}/#{@prefix}/fs_test/"))
      assert_true(@fs.exist?("gs://#{@bucket}/#{@prefix}/fs_test/#{@keys[0]}"))
    end

    test "false" do
      assert_false(@fs.exist?("gs://#{@bucket}/#{@prefix}/fs_test/not_found_dir/"))
      assert_false(@fs.exist?("gs://#{@bucket}/#{@prefix}/fs_test/not_found_file.txt"))
    end
  end

  sub_test_case "remove" do
    test "cannot delete root" do
      assert_raise(Tumugi::FileSystemError) do
        @fs.remove("gs://#{@bucket}")
      end
    end

    test "exist file" do
      assert_true(@fs.remove("gs://#{@bucket}/#{@prefix}/fs_test/#{@keys[0]}"))
    end

    test "non exist file" do
      assert_false(@fs.remove("gs://#{@bucket}/#{@prefix}/fs_test/not_found.txt"))
    end

    test "directory without recursive flag" do
      assert_raise(Tumugi::FileSystemError) do
        @fs.remove("gs://#{@bucket}/#{@prefix}/fs_test/", recursive: false)
      end
    end

    test "directory also delete child files" do
      assert_true(@fs.remove("gs://#{@bucket}/#{@prefix}/fs_test/"))
      assert_equal(0, @fs.entries("gs://#{@bucket}/#{@prefix}/fs_test/").count)
    end
  end

  sub_test_case "mkdir" do
    test "return true when success" do
      assert_true(@fs.mkdir("gs://#{@bucket}/#{@prefix}/fs_test/new_dir/"))
    end

    sub_test_case "path is already exist" do
      test "raise error if raise_if_exist flag is true" do
        assert_raise(Tumugi::FileAlreadyExistError) do
          @fs.mkdir("gs://#{@bucket}/#{@prefix}/fs_test/", raise_if_exist: true)
        end
      end

      test "raise error if path is not a directory" do
        assert_raise(Tumugi::NotADirectoryError) do
          @fs.mkdir("gs://#{@bucket}/#{@prefix}/fs_test/#{@keys[0]}")
        end
      end

      test "return false" do
        assert_false(@fs.mkdir("gs://#{@bucket}/#{@prefix}/fs_test/"))
      end
    end
  end

  data({
    "root" => [ true, "" ],
    "exist" => [ true, "fs_test/" ],
    "prefix" => [ true, "fs_test/folder" ],
    "not_a_folder" => [ false, "fs_test/not_a_folder" ]
  })
  test "directory?" do |(expected, path)|
    assert_equal(expected, @fs.directory?("gs://#{@bucket}/#{@prefix}/#{path}"))
  end

  sub_test_case "entries" do
    test "path has entries" do
      entries = @fs.entries("gs://#{@bucket}/#{@prefix}/fs_test/")
      assert_equal(@keys.count, entries.count)
      @keys.each_with_index do |key, i|
        assert_equal(@bucket, entries[i].bucket)
        assert_equal("#{@prefix}/fs_test/#{key}", entries[i].name)
      end
    end

    test "path has no entry" do
      entries = @fs.entries("gs://#{@bucket}/#{@prefix}/fs_test/no_entries/")
      assert_true(entries.empty?)
    end
  end

  sub_test_case "move" do
    test "directory" do
      src_path = "gs://#{@bucket}/#{@prefix}/fs_test/"
      dest_path = "gs://#{@bucket}/#{@prefix}/fs_dest/"

      @fs.move(src_path, dest_path)

      assert_false(@fs.exist?(src_path))
      entries = @fs.entries(dest_path)
      assert_equal(@keys.count, entries.count)
      @keys.each_with_index do |key, i|
        assert_equal(@bucket, entries[i].bucket)
        assert_equal("#{@prefix}/fs_dest/#{key}", entries[i].name)
      end
    end
  end

  test "upload" do
    new_file_path = "gs://#{@bucket}/#{@prefix}/fs_test/new_file.txt"
    @fs.upload(StringIO.new('upload'), new_file_path)
    assert_true(@fs.exist?(new_file_path))
  end

  sub_test_case "download" do
    test "without block" do
      f = @fs.download("gs://#{@bucket}/#{@prefix}/fs_test/#{@keys[0]}", download_path: 'tmp/download.txt')
      assert_true(File.exist?('tmp/download.txt'))
      assert_equal('test', f.read)
      f.close
    end

    test "with block, without destination file name" do
      @fs.download("gs://#{@bucket}/#{@prefix}/fs_test/#{@keys[0]}") do |f|
        assert_equal('test', f.read)
      end
    end
  end

  sub_test_case "copy" do
    test "directory" do
      src_path = "gs://#{@bucket}/#{@prefix}/fs_test/"
      dest_path = "gs://#{@bucket}/#{@prefix}/fs_dest/"

      @fs.copy(src_path, dest_path)

      entries = @fs.entries(dest_path)
      assert_equal(@keys.count, entries.count)
      @keys.each_with_index do |key, i|
        assert_equal(@bucket, entries[i].bucket)
        assert_equal("#{@prefix}/fs_dest/#{key}", entries[i].name)
      end
    end

    test "raise_if_exist" do
      assert_raise(Tumugi::FileAlreadyExistError) do
        src_path = "gs://#{@bucket}/#{@prefix}/fs_test/"
        dest_path = "gs://#{@bucket}/#{@prefix}/fs_test/"
        @fs.copy(src_path, dest_path, raise_if_exist: true)
      end
    end
  end

  sub_test_case "path_to_bucket_and_key" do
    test "success" do
      result = @fs.path_to_bucket_and_key("gs://bucket/path/to/object")
      assert_equal('bucket', result[0])
      assert_equal('path/to/object', result[1])
    end

    test "raise error when scheme is not 'gs'" do
      assert_raise(Tumugi::FileSystemError) do
        @fs.path_to_bucket_and_key("https://bucket/path/to/object")
      end
    end
  end

  test "bucket releated methods" do
    bucket = "tumugi-plugin-gcs-#{SecureRandom.hex(10)}"
    assert_false(@fs.bucket_exist?(bucket))
    assert_true(@fs.create_bucket(bucket))
    assert_true(@fs.bucket_exist?(bucket))
    assert_true(@fs.remove_bucket(bucket))
    assert_false(@fs.bucket_exist?(bucket))
  end
end
