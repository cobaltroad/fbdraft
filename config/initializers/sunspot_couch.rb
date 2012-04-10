module Sunspot
  module Couch
    module Adapters
      class CouchInstanceAdapter < Sunspot::Adapters::InstanceAdapter
        def id
          @instance.id
        end
      end

      class CouchDataAccessor < Sunspot::Adapters::DataAccessor
        def load(id)
          @clazz.find(id)
        end
      end
    end
  end
end