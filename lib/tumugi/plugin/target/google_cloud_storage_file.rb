require 'tumugi/config'
require 'tumugi/plugin'
require 'tumugi/plugin/file_system_target'
require 'tumugi/plugin/google_cloud_storage/atomic_file'
require 'tumugi/plugin/google_cloud_storage/file_system'

module Tumugi
  module Plugin
    class GoogleCloudStorageFileTarget < Tumugi::Plugin::FileSystemTarget
      Tumugi::Plugin.register_target('google_cloud_storage_file', self)
      Tumugi::Config.register_section('google_cloud_storage', :project_id, :client_email, :private_key, :private_key_file)

      attr_reader :bucket, :key, :path

      def initialize(bucket:, key:, fs: nil)
        @bucket = bucket
        @key = key
        @path = "gs://#{File.join(bucket, key)}"
        @fs = fs unless fs.nil?
        log "bucket='#{bucket}, key='#{key}'"
      end

      def fs
        @fs ||= Tumugi::Plugin::GoogleCloudStorage::FileSystem.new(Tumugi.config.section('google_cloud_storage'))
      end

      def open(mode="r", &block)
        if mode.include? 'r'
          fs.download(path, mode: mode, &block)
        elsif mode.include? 'w'
          Tumugi::Plugin::GoogleCloudStorage::AtomicFile.new(path, fs).open(&block)
        else
          raise Tumugi::TumugiError.new('Invalid mode: #{mode}')
        end
      end

      def to_s
        path
      end
    end
  end
end
