require 'rubygems'
require 'active_record'
require 'test/unit'
require 'shoulda'

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'serialize_with_options'
require File.dirname(__FILE__) + "/../init"

# Include logger
require 'logger'
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::INFO
ActiveRecord::Migration.verbose = false

# Set some Rails 3 defaults for json encoding
ActiveRecord::Base.include_root_in_json = true
ActiveSupport.use_standard_json_time_format = true
ActiveSupport.escape_html_entities_in_json = false

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

[:users, :posts, :comments, :check_ins, :reviews].each do |table|
  ActiveRecord::Base.connection.drop_table table rescue nil
end

ActiveRecord::Base.connection.create_table :users do |t|
  t.string :name
  t.string :email
end

ActiveRecord::Base.connection.create_table :posts do |t|
  t.string :title
  t.text :content
  t.integer :user_id
  t.string :type
end

ActiveRecord::Base.connection.create_table :comments do |t|
  t.text :content
  t.integer :post_id
end

ActiveRecord::Base.connection.create_table :check_ins do |t|
  t.integer :user_id
  t.string :code_name
end

ActiveRecord::Base.connection.create_table :reviews do |t|
  t.string :content
  t.integer :reviewable_id
  t.string :reviewable_type
end

