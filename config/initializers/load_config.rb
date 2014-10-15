
BASE_DIR = File.dirname(Dir.pwd)

APP_CONFIG = YAML.load_file("#{BASE_DIR}/cite_collections_rails/config/config.yml")[Rails.env]