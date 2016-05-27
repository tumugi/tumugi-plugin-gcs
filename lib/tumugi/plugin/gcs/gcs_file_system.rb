require 'uri'
require 'google/apis/storage_v1'
require 'tumugi/file_system'

module Tumugi
  module Plugin
    module GCS
      class GCSFileSystem < Tumugi::FileSystem
        attr_reader :client

        def initialize(config)
          @project_id = config[:project_id] || config.project_id
          @client = create_client(config)
        end

        #######################################################################
        # FileSystem interfaces
        #######################################################################

        def exist?(path)
          bucket, key = path_to_bucket_and_key(path)
          if obj_exist?(bucket, key)
            true
          else
            directory?(path)
          end
        end

        def remove(path, recursive: true)
          bucket, key = path_to_bucket_and_key(path)
          raise Tumugi::FileSystemError.new("Cannot delete root of bucket at path '#{path}'") if root?(key)

          if obj_exist?(bucket, key)
            @client.delete_object(bucket, key)
            wait_until { !obj_exist?(bucket, key) }
            true
          elsif directory?(path)
            raise Tumugi::FileSystemError.new("Path '#{path}' is a directory. Must use recursive delete") if !recursive

            objs = entries(path).map(&:name)
            @client.batch do |client|
              objs.each do |obj|
                client.delete_object(bucket, obj)
              end
            end
            wait_until { !directory?(path) }
            true
          else
            false
          end
        end

        def mkdir(path, parents: true, raise_if_exist: false)
          if exist?(path)
            if raise_if_exist
              raise Tumugi::FileAlreadyExistError.new("Path #{path} is already exist")
            elsif !directory?(path)
              raise Tumugi::NotADirectoryError.new("Path #{path} is not a directory")
            end
            false
          else
            put_string("", add_path_delimiter(path))
            true
          end
        end

        def directory?(path)
          bucket, key = path_to_bucket_and_key(path)
          if root?(key)
            bucket_exist?(bucket)
          else
            obj = add_path_delimiter(key)
            if obj_exist?(bucket, obj)
              true
            else
              # Any objects with this prefix
              objects = @client.list_objects(bucket, prefix: obj, max_results: 20)
              !!(objects.items && objects.items.size > 0)
            end
          end
        end

        def entries(path)
          bucket, key = path_to_bucket_and_key(path)
          obj = add_path_delimiter(key)
          results = []
          next_page_token = ''

          until next_page_token.nil?
            objects = @client.list_objects(bucket, prefix: obj, page_token: next_page_token)
            if objects && objects.items
              results.concat(objects.items)
              next_page_token = objects.next_page_token
            else
              next_page_token = nil
            end
          end
          results
        end

        def move(src_path, dest_path, raise_if_exist: false)
          copy(src_path, dest_path, raise_if_exist: raise_if_exist)
          remove(src_path)
        end

        #######################################################################
        # Specific methods
        #######################################################################

        def upload(media, path, content_type: 'application/octet-stream')
          bucket, key = path_to_bucket_and_key(path)
          obj = Google::Apis::StorageV1::Object.new(bucket: bucket, name: key)
          @client.insert_object(bucket, obj, upload_source: media, content_type: content_type)
          wait_until { obj_exist?(bucket, key) }
        end

        def download(path, download_dest)
          bucket, key = path_to_bucket_and_key(path)
          @client.get_object(bucket, key, download_dest: download_dest)
          wait_until { File.exist?(download_dest) }
        end

        def put_string(contents, path, content_type: 'text/plain')
          media = StringIO.new(contents)
          upload(media, path, content_type: content_type)
        end

        def copy(src_path, dest_path, raise_if_exist: false)
          src_bucket, src_key = path_to_bucket_and_key(src_path)
          dest_bucket, dest_key = path_to_bucket_and_key(dest_path)

          if directory?(src_path)
            src_prefix = add_path_delimiter(src_key)
            dest_prefix = add_path_delimiter(dest_key)

            src_path = add_path_delimiter(src_path)
            copied_objs = []
            entries(src_path).each do |entry|
              suffix = entry.name[src_prefix.length..-1]
              @client.copy_object(src_bucket, src_prefix + suffix,
                                  dest_bucket, dest_prefix + suffix)
              copied_objs << (dest_prefix + suffix)
            end
            wait_until { copied_objs.all? {|obj| obj_exist?(dest_bucket, obj)} }
          else
            @client.copy_object(src_bucket, src_key, dest_bucket, dest_key)
            wait_until { obj_exist?(dest_bucket, dest_key) }
          end
        end

        def path_to_bucket_and_key(path)
          uri = URI.parse(path)
          raise Tumugi::FileSystemError.new("URI scheme must be 'gs' but '#{uri.scheme}'") unless uri.scheme == 'gs'
          [ uri.host, uri.path[1..-1] ]
        end

        private

        def obj_exist?(bucket, key)
          @client.get_object(bucket, key)
          true
        rescue => e
          return false if e.status_code == 404
          raise Tumugi::FileSystemError.new(e.message)
        end

        def bucket_exist?(bucket)
          @client.get_bucket(bucket)
          true
        rescue => e
          return false if e.status_code == 404
          raise Tumugi::FileSystemError.new(e.message)
        end

        def root?(key)
          key.nil? || key == ''
        end

        def add_path_delimiter(key)
          if key.end_with?('/')
            key
          else
            "#{key}/"
          end
        end

        def create_client(config)
          client_email = config[:client_email] || config.client_email
          private_key = config[:private_key] || config.private_key

          # https://cloud.google.com/storage/docs/authentication
          scope = "https://www.googleapis.com/auth/devstorage.read_write"

          if client_email and private_key
            auth = Signet::OAuth2::Client.new(
              token_credential_uri: "https://accounts.google.com/o/oauth2/token",
              audience: "https://accounts.google.com/o/oauth2/token",
              scope: scope,
              issuer: client_email,
              signing_key: OpenSSL::PKey.read(private_key))
            # MEMO: signet-0.6.1 depend on Farady.default_connection
            Faraday.default_connection.options.timeout = 60
            auth.fetch_access_token!
          else
            auth = Google::Auth.get_application_default([scope])
            auth.fetch_access_token!
          end

          client = Google::Apis::StorageV1::StorageService.new
          client.authorization = auth
          client
        end

        def wait_until(&block)
          while not block.call
            sleep 1
          end
        end
      end
    end
  end
end
