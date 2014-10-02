# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
CiteCollections::Application.initialize!

ENV['RAILS_RELATIVE_URL_ROOT'] = '/cite-collections'