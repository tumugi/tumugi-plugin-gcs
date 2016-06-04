require 'uri'
require 'json'
require 'googleauth/service_account'
require 'google/apis/storage_v1'
require 'google/apis/drive_v3'
require 'tumugi/file_system'

module Tumugi
  module Plugin
    module GoogleCloudStorage
      class FileSystem < Tumugi::FileSystem
        attr_reader :client

        def initialize(config)
          save_config(config)
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
        rescue
          process_error($!)
        end

        def remove(path, recursive: true)
          bucket, key = path_to_bucket_and_key(path)
          raise Tumugi::FileSystemError.new("Cannot delete root of bucket at path '#{path}'") if root?(key)

          if obj_exist?(bucket, key)
            client.delete_object(bucket, key, options: request_options)
            wait_until { !obj_exist?(bucket, key) }
            true
          elsif directory?(path)
            raise Tumugi::FileSystemError.new("Path '#{path}' is a directory. Must use recursive delete") if !recursive

            objs = entries(path).map(&:name)
            client.batch do |client|
              objs.each do |obj|
                client.delete_object(bucket, obj, options: request_options)
              end
            end
            wait_until { !directory?(path) }
            true
          else
            false
          end
        rescue
          process_error($!)
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
        rescue
          process_error($!)
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
              objects = client.list_objects(bucket, prefix: obj, max_results: 20, options: request_options)
              !!(objects.items && objects.items.size > 0)
            end
          end
        rescue
          process_error($!)
        end

        def entries(path)
          bucket, key = path_to_bucket_and_key(path)
          obj = add_path_delimiter(key)
          results = []
          next_page_token = ''

          until next_page_token.nil?
            objects = client.list_objects(bucket, prefix: obj, page_token: next_page_token, options: request_options)
            if objects && objects.items
              results.concat(objects.items)
              next_page_token = objects.next_page_token
            else
              next_page_token = nil
            end
          end
          results
        rescue
          process_error($!)
        end

        def move(src_path, dest_path, raise_if_exist: false)
          copy(src_path, dest_path, raise_if_exist: raise_if_exist)
          remove(src_path)
        end

        #######################################################################
        # Specific methods
        #######################################################################

        def upload(media, path, content_type: nil)
          bucket, key = path_to_bucket_and_key(path)
          obj = Google::Apis::StorageV1::Object.new(bucket: bucket, name: key)
          client.insert_object(bucket, obj, upload_source: media, content_type: content_type, options: request_options)
          wait_until { obj_exist?(bucket, key) }
        rescue
          process_error($!)
        end

        def download(path, download_path: nil, mode: 'r', &block)
          bucket, key = path_to_bucket_and_key(path)
          if download_path.nil?
            download_path = Tempfile.new('tumugi_gcs_file_system').path
          end
          client.get_object(bucket, key, download_dest: download_path, options: request_options)
          wait_until { File.exist?(download_path) }

          if block_given?
            File.open(download_path, mode, &block)
          else
            File.open(download_path, mode)
          end
        rescue
          process_error($!)
        end

        def put_string(contents, path, content_type: 'text/plain')
          media = StringIO.new(contents)
          upload(media, path, content_type: content_type)
        end

        def copy(src_path, dest_path, raise_if_exist: false)
          if raise_if_exist && exist?(dest_path)
            raise Tumugi::FileAlreadyExistError.new("Path #{dest_path} is already exist")
          end

          src_bucket, src_key = path_to_bucket_and_key(src_path)
          dest_bucket, dest_key = path_to_bucket_and_key(dest_path)

          if directory?(src_path)
            src_prefix = add_path_delimiter(src_key)
            dest_prefix = add_path_delimiter(dest_key)

            src_path = add_path_delimiter(src_path)
            copied_objs = []
            entries(src_path).each do |entry|
              suffix = entry.name[src_prefix.length..-1]
              client.copy_object(src_bucket, src_prefix + suffix,
                                  dest_bucket, dest_prefix + suffix, options: request_options)
              copied_objs << (dest_prefix + suffix)
            end
            wait_until { copied_objs.all? {|obj| obj_exist?(dest_bucket, obj)} }
          else
            client.copy_object(src_bucket, src_key, dest_bucket, dest_key, options: request_options)
            wait_until { obj_exist?(dest_bucket, dest_key) }
          end
        rescue
          process_error($!)
        end

        def path_to_bucket_and_key(path)
          uri = URI.parse(path)
          raise Tumugi::FileSystemError.new("URI scheme must be 'gs' but '#{uri.scheme}'") unless uri.scheme == 'gs'
          [ uri.host, uri.path[1..-1] ]
        end

        def create_bucket(bucket)
          unless bucket_exist?(bucket)
            b = Google::Apis::StorageV1::Bucket.new(name: bucket)
            client.insert_bucket(@project_id, b, options: request_options)
            true
          else
            false
          end
        rescue
          process_error($!)
        end

        def remove_bucket(bucket)
          if bucket_exist?(bucket)
            client.delete_bucket(bucket, options: request_options)
            true
          else
            false
          end
        rescue
          process_error($!)
        end

        def bucket_exist?(bucket)
          client.get_bucket(bucket, options: request_options)
          true
        rescue => e
          return false if e.status_code == 404
          process_error(e)
        end

        private

        def obj_exist?(bucket, key)
          client.get_object(bucket, key, options: request_options)
          true
        rescue => e
          return false if e.status_code == 404
          process_error(e)
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

        def save_config(config)
          if config.private_key_file.nil?
            @project_id = config.project_id
            client_email = config.client_email
            private_key = config.private_key
          else
            json = JSON.parse(File.read(config.private_key_file))
            @project_id = json['project_id']
            client_email = json['client_email']
            private_key = json['private_key']
          end
          @key = {
            client_email: client_email,
            private_key: private_key
          }
        end

        def client
          return @cached_client if @cached_client && @cached_client_expiration > Time.now

          client = Google::Apis::StorageV1::StorageService.new
          scope = Google::Apis::StorageV1::AUTH_DEVSTORAGE_READ_WRITE

          if @key[:client_email] and @key[:private_key]
            options = {
              json_key_io: StringIO.new(JSON.generate(@key)),
              scope: scope
            }
            auth = Google::Auth::ServiceAccountCredentials.make_creds(options)
          else
            auth = Google::Auth.get_application_default([scope])
          end
          auth.fetch_access_token!
          client.authorization = auth

          @cached_client_expiration = Time.now + (auth.expires_in / 2)
          @cached_client = client
        end

        def request_options
          {
            retries: 5,
            timeout_sec: 60
          }
        end

        def wait_until(&block)
          while not block.call
            sleep 1
          end
        end

        def process_error(err)
          if err.respond_to?(:body)
            begin
              jobj = JSON.parse(err.body)
              error = jobj["error"]
              reason = error["errors"].map{|e| e["reason"]}.join(",")
              errors = error["errors"].map{|e| e["message"] }.join("\n")
            rescue JSON::ParserError
              reason = err.status_code.to_s
              errors = "HTTP Status: #{err.status_code}\nHeaders: #{err.header.inspect}\nBody:\n#{err.body}"
            end
            raise Tumugi::FileSystemError.new(errors, reason)
          else
            raise err
          end
        end
      end
    end
  end
end
