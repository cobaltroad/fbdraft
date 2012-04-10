require Rails.root.join('config','initializers','sunspot_couch.rb')

CouchRest::Model::Base.configure do |config|
  config.connection = {
    :protocol => "http",
    :host     => "localhost",
    :port     => "5984",
    :prefix   => "fbdraft",
    :suffix   => Rails.env,
    :join     => '_',
    :username => nil,
    :password => nil
  }
end

Sunspot::Adapters::InstanceAdapter.register(Sunspot::Couch::Adapters::CouchInstanceAdapter, CouchRest::Model::Base)
Sunspot::Adapters::DataAccessor.register(Sunspot::Couch::Adapters::CouchDataAccessor, CouchRest::Model::Base)