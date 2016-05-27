require 'tumugi/atomic_file'

module Tumugi
  module Plugin
    module GCS
      class AtomicGCSFile < Tumugi::AtomicFile
        def initialize(path, client)
          super(path)
          @client = client
        end

        def move_to_final_destination(temp_file)
          @client.upload(temp_file, path)
        end
      end
    end
  end
end
