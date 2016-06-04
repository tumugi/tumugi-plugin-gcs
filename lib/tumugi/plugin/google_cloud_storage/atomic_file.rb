require 'tumugi/atomic_file'

module Tumugi
  module Plugin
    module GoogleCloudStorage
      class AtomicFile < Tumugi::AtomicFile
        def initialize(path, fs)
          super(path)
          @fs = fs
        end

        def move_to_final_destination(temp_file)
          @fs.upload(temp_file, path)
        end
      end
    end
  end
end
