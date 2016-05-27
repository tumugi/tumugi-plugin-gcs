require 'tumugi/config'
require 'tumugi/plugin'
require 'tumugi/plugin/file_system_target'
require 'tumugi/plugin/gcs/atomic_gcs_file'
require 'tumugi/plugin/gcs/gcs_file_system'

module Tumugi
  module Plugin
    class GCSFileTarget < Tumugi::Plugin::FileSystemTarget
      Tumugi::Plugin.register_target('gcs_file', self)
      Tumugi::Config.register_section('gcs', :project_id, :client_email, :private_key)

      attr_reader :bucket, :key, :path

      def initialize(bucket:, key:)
        @bucket = bucket
        @key = key
        @path = "gs://#{File.join(bucket, key)}"
        log "bucket='#{bucket}, key='#{key}'"
      end

      def fs
        @fs ||= Tumugi::Plugin::GCS::GCSFileSystem.new(Tumugi.config.section('gcs'))
      end

      def client
        fs.client
      end

      def open(mode="r", &block)
        if mode.include? 'r'
          fs.download(path)
        elsif mode.include? 'w'
          Tumugi::Plugin::GCS::AtomicGCSFile.new(path, fs).open(&block)
        else
          raise 'Invalid mode: #{mode}'
        end
      end

      def to_s
        path
      end
    end
  end
end
