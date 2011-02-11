require 'test_helper'

class User < ActiveRecord::Base
  has_many :posts
  has_many :blog_posts
  has_many :reviews, :as => :reviewable

  serialize_with_options do
    methods   :post_count
    except    :email
  end

  serialize_with_options(:with_other_method) do
    methods   :other_method
  end
  
  serialize_with_options(:with_optional_methods) do
    optional_methods [:post_count, :add_post_count?]
  end
  
  serialize_with_options(:with_optional_and_normal_methods) do
    methods :other_method
    optional_methods [:post_count, :add_post_count?]
  end
  
  serialize_with_options(:only_email) do
    only :email
  end
  
  serialize_with_options(:inherit_from) do
    only    :email
    methods :post_count
  end
  
  serialize_with_options(:inherited => :inherit_from) do
    methods   :other_method
  end
  
  serialize_with_options(:return_nil_on) do
    return_nil_on :email
  end
  
  def post_count
    self.posts.count
  end
  
  def other_method
    "foo value"
  end
  
  def add_post_count?
    @add_post_count
  end
  
  def add_post_count=(add_post_count)
    @add_post_count = add_post_count
  end
end

class Post < ActiveRecord::Base
  belongs_to :user
  has_many :reviews, :as => :reviewable

  serialize_with_options do
    only :title
  end
end

class BlogPost < Post
  serialize_with_options do
    only :title, :content
  end
end

class SerializeWithOptionsTest < Test::Unit::TestCase
  def self.should_serialize_with_options
    should "include active_record attributes" do
      assert_equal @user.name, @user_hash["name"]
    end

    should "include specified methods" do
      assert_equal @user.post_count, @user_hash["post_count"]
    end

    should "exclude specified attributes" do
      assert_equal nil, @user_hash["email"]
    end

    should "exclude attributes not in :only list" do
      assert_equal nil, @post_hash["content"]
    end
    
    should "be identical in inherited model" do
      assert_equal @post_hash["title"], @blog_post_hash["title"]
    end

    should "override sets on inherited models" do
      assert_equal nil,           @post_hash["content"]
      assert_equal "Welcome to my blog.", @blog_post_hash["content"]
    end
  end

  context "An instance of a class with serialization options" do
    setup do
      @user = User.create(:name => "John User", :email => "john@example.com")
      @post = @user.posts.create(:title => "Hello World!", :content => "Welcome to my blog.")
      @blog_post = @user.blog_posts.create(:title => "Hello World!", :content => "Welcome to my blog.")
    end

    context "being converted to XML" do
      setup do
        @user_hash = Hash.from_xml(@user.to_xml)["user"]
        @post_hash = Hash.from_xml(@post.to_xml)["post"]
        @blog_post_hash = Hash.from_xml(@blog_post.to_xml)["blog_post"]
      end

      should_serialize_with_options
    end


    # should "accept additional properties w/o overwriting defaults" do
    #   xml = @user.to_xml(:methods => [:other_method])
    #   user_hash = Hash.from_xml(xml)["user"]
    # 
    #   assert_equal @user.email,         user_hash["email"]
    #   assert_equal nil,                 user_hash["post_count"]
    #   assert_equal @user.other_method,  user_hash["other_method"]
    # end

    context "with a secondary configuration" do
      setup do
        @user_hash = Hash.from_xml(@user.to_xml(:with_other_method))["user"]
      end
      
      should "not be based on other configurations" do
        assert_equal @user.email, @user_hash["email"]
      end
      
      should "use it" do
        assert_equal @user.other_method, @user_hash["other_method"]
      end
    end

    context "being converted to JSON" do
      setup do
        @user_hash = ActiveSupport::JSON.decode(@user.to_json)['user']
        @post_hash = ActiveSupport::JSON.decode(@post.to_json)['post']
        @blog_post_hash = ActiveSupport::JSON.decode(@blog_post.to_json)['blog_post']
      end

      should_serialize_with_options
    end
    
    context "being converted to JSON by ActiveSupport::JSON.encode" do
      setup do
        @user_hash = ActiveSupport::JSON.decode(ActiveSupport::JSON.encode(@user))['user']
        @post_hash = ActiveSupport::JSON.decode(ActiveSupport::JSON.encode(@post))['post']
        @blog_post_hash = ActiveSupport::JSON.decode(ActiveSupport::JSON.encode(@blog_post))['blog_post']
      end
      
      should_serialize_with_options
      
      should "produce same result as to_json" do
        assert_equal @user.to_json, ActiveSupport::JSON.encode(@user)
        assert_equal @user.to_json(:all), ActiveSupport::JSON.encode(@user, :all)
      end
    end
  
    context "with optional_methods" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
      end
      
      context "if add_post_count? returns true" do
        setup do
          @user.add_post_count = true
        end
        
        should "add post_count" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_methods))['user']
          assert user_hash.keys.include?("post_count")
          assert_equal 0, user_hash['post_count']
        end
        
        should "add normal methods" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_and_normal_methods))['user']
          assert_equal 'foo value', user_hash['other_method']
          assert_equal 0, user_hash['post_count']
        end
      end
      
      context "if add_post_count? returns false" do
        setup do
          @user.add_post_count = false
        end
        
        should "not add post_count" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_methods))['user']
          assert !user_hash.keys.include?("post_count")
          assert_equal nil, user_hash['post_count']
        end
        
        should "add normal methods" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_and_normal_methods))['user']
          assert_equal 'foo value', user_hash['other_method']
          assert_equal nil, user_hash['post_count']
        end
      end
      
      context "if add_post_count? returns nil" do
        setup do
          @user.add_post_count = nil
        end
        
        should "not add post_count" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_methods))['user']
          assert !user_hash.keys.include?("post_count")
          assert_equal nil, user_hash['post_count']
        end
        
        should "add normal methods" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_and_normal_methods))['user']
          assert_equal 'foo value', user_hash['other_method']
          assert_equal nil, user_hash['post_count']
        end
      end
    
      context "if add_post_count changes" do
        setup do
          @user.add_post_count = true
        end
        
        should "add post_count first and remove it when add_post_count changes" do
          user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_optional_and_normal_methods))['user']
          assert user_hash.keys.include?("post_count")
          assert_equal 0, user_hash['post_count']
          @user.add_post_count = false
          user_hash2 = ActiveSupport::JSON.decode(@user.to_json(:with_optional_and_normal_methods))['user']
          assert !user_hash2.keys.include?("post_count")
        end
      end
    end
  
    context "default :all option" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
      end
      
      should "include all db columns when serialized to xml" do
        user_keys = Hash.from_xml(@user.to_xml(:all))["user"].keys.sort
        assert_equal @user.class.column_names.sort, user_keys
      end
      
      should "include all db columns when serialized to json" do
        user_keys = ActiveSupport::JSON.decode(@user.to_json(:all))["user"].keys.sort
        assert_equal @user.class.column_names.sort, user_keys
      end
    end
    
    context "specifing the configuration set alternativly in the options hash as :set" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
      end
      
      should "format to_xml correctly" do
        assert_equal @user.to_xml(:all), @user.to_xml(:set => :all)
      end
      
      should "format to_json correctly" do
        assert_equal @user.to_json(:all), @user.to_json(:set => :all)
      end
    end
    
    context "objects in array" do
      setup do
        @users = [User.create(:name => "John User", :email => "john@example.com")]
      end
      
      should "work with to_xml" do
        assert_equal Hash.from_xml(@users.first.to_xml(:all))["user"], Hash.from_xml(@users.to_xml(:set => :all))["users"].first
      end
      
      should "work with to_json" do
        assert_equal ActiveSupport::JSON.decode(@users.first.to_json(:all)), ActiveSupport::JSON.decode(@users.to_json(:set => :all)).first
      end
      
    end
    
    context "only" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
      end
      
      should "adds only attributes specified with only" do
        user_hash = ActiveSupport::JSON.decode(@user.to_json(:only_email))['user']
        assert_equal ["email"], user_hash.keys
        assert_equal "john@example.com", user_hash['email']
        user_hash = Hash.from_xml(@user.to_xml(:only_email))['user']
        assert_equal ["email"], user_hash.keys
        assert_equal "john@example.com", user_hash['email']
      end
    end
    
    context "inherit options" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
      end
      
      should "adds options given in own block" do
        user_hash = ActiveSupport::JSON.decode(@user.to_json(:inherited))['user']
        assert user_hash.keys.include?("other_method")
        user_hash = Hash.from_xml(@user.to_xml(:inherited))['user']
        assert user_hash.keys.include?("other_method")
      end
      
      should "inherit from given parent" do
        user_hash = ActiveSupport::JSON.decode(@user.to_json(:inherited))['user']
        assert user_hash.keys.include?("email")
        assert !user_hash.keys.include?("name")
        user_hash = Hash.from_xml(@user.to_xml(:inherited))['user']
        assert user_hash.keys.include?("email")
        assert !user_hash.keys.include?("name")
      end
      
      should "overwrite options" do
        user_hash = ActiveSupport::JSON.decode(@user.to_json(:inherited))['user']
        assert !user_hash.keys.include?("post_count")
        user_hash = Hash.from_xml(@user.to_xml(:inherited))['user']
        assert !user_hash.keys.include?("post_count")
      end
    end
    
    context "return_nil_on" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
      end
      
      should "overwrite value of given attributes with nil but include them" do
        user_hash = ActiveSupport::JSON.decode(@user.to_json(:return_nil_on))['user']
        user_hash.keys.include?("email")
        assert_equal nil, user_hash['email']
        user_hash = Hash.from_xml(@user.to_xml(:return_nil_on))['user']
        user_hash.keys.include?("email")
        assert_equal nil, user_hash['email']
      end
      
      should "not change attributes and preserve changes of instance" do
        @user.email = "me@theweb.com"
        @user.to_json(:return_nil_on)
        assert_equal({"email" => ["john@example.com", "me@theweb.com"]}, @user.changes)
        [@user].to_json(:set => :return_nil_on)
        assert_equal({"email" => ["john@example.com", "me@theweb.com"]}, @user.changes)
        @user.to_xml(:return_nil_on)
        assert_equal({"email" => ["john@example.com", "me@theweb.com"]}, @user.changes)
      end
    end
  end
end
