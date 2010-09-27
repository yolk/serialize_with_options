require 'test_helper'

class User < ActiveRecord::Base
  has_many :posts
  has_many :blog_posts
  has_many :check_ins
  has_many :reviews, :as => :reviewable

  serialize_with_options do
    methods   :post_count
    includes  :posts
    except    :email
  end

  serialize_with_options(:with_email) do
    methods   :post_count
    includes  :posts
  end

  serialize_with_options(:with_comments) do
    includes  :posts => { :include => :comments }
  end

  serialize_with_options(:with_check_ins) do
    includes :check_ins
    dasherize false
    skip_types true
  end

  serialize_with_options(:with_reviews) do
    includes :reviews
  end
  
  serialize_with_options(:with_optional_methods) do
    optional_methods [:post_count, :add_post_count?]
  end
  
  serialize_with_options(:with_optional_and_normal_methods) do
    methods :other_method
    optional_methods [:post_count, :add_post_count?]
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
  has_many :comments
  has_many :reviews, :as => :reviewable

  serialize_with_options do
    only :title
    includes :user, :comments
  end

  serialize_with_options(:with_email) do
    includes :user, :comments
  end
end

class BlogPost < Post
  serialize_with_options(:with_email) do
    includes :user
  end
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

class CheckIn < ActiveRecord::Base
  belongs_to :user

  serialize_with_options do
    only :code_name
    includes :user
  end
end

class Review < ActiveRecord::Base
  belongs_to :reviewable, :polymorphic => true

  serialize_with_options do
    includes :reviewable
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

    should "include specified associations" do
      assert_equal @post.title, @user_hash["posts"].first["title"]
    end

    should "be identical in inherited model" do
      assert_equal @post_hash["title"], @blog_post_hash["title"]
    end

    should "include specified methods on associations" do
      assert_equal @user.post_count, @post_hash["user"]["post_count"]
    end

    should "exclude specified methods on associations" do
      assert_equal nil,  @post_hash["user"]["email"]
    end

    should "not include associations of associations" do
      assert_equal nil, @user_hash["posts"].first["comments"]
    end

    should "include association without serialization options properly" do
      assert_equal @comment.content, @post_hash["comments"].first["content"]
    end

    should "override sets on inherited models" do
      assert_equal nil, @blog_post_hash["comments"].first
    end
  end

  context "An instance of a class with serialization options" do
    setup do
      @user = User.create(:name => "John User", :email => "john@example.com")
      @post = @user.posts.create(:title => "Hello World!", :content => "Welcome to my blog.")
      @blog_post = @user.blog_posts.create(:title => "Hello World!", :content => "Welcome to my blog.")
      @comment = @post.comments.create(:content => "Great blog!")
    end

    context "being converted to XML" do
      setup do
        @user_hash = Hash.from_xml(@user.to_xml)["user"]
        @post_hash = Hash.from_xml(@post.to_xml)["post"]
        @blog_post_hash = Hash.from_xml(@blog_post.to_xml)["blog_post"]
      end

      should_serialize_with_options
    end


    should "accept additional properties w/o overwriting defaults" do
      xml = @post.to_xml(:include => { :user => { :except => nil } })
      post_hash = Hash.from_xml(xml)["post"]

      assert_equal @user.email,       post_hash["user"]["email"]
      assert_equal @user.post_count,  post_hash["user"]["post_count"]
    end

    should "accept a hash for includes directive" do
      user_hash = Hash.from_xml(@user.to_xml(:with_comments))["user"]
      assert_equal @comment.content, user_hash["posts"].first["comments"].first["content"]
    end

    context "with a secondary configuration" do
      should "use it" do
        user_hash = Hash.from_xml(@user.to_xml(:with_email))["user"]
        assert_equal @user.email, user_hash["email"]
      end

      should "pass it through to included models" do
        post_hash = Hash.from_xml(@post.to_xml(:with_email))["post"]
        assert_equal @user.email, post_hash["user"]["email"]
      end
    
      context "combinded with additional options" do
        setup do
          @review = Review.create(:reviewable => @user, :content => "troll")
        end
        
        should "use secondary configuration" do
          user_hash = Hash.from_xml(@user.to_xml(:with_email, {:include => :reviews}))["user"]
          assert_equal @user.email, user_hash["email"]
        end
        
        should "use additional options and overwrite properties from set" do
          user_hash = Hash.from_xml(@user.to_xml(:with_email, {:include => :reviews}))["user"]
          assert_equal @review.content, user_hash["reviews"].first["content"]
          assert_equal nil, user_hash["posts"]
        end
      end
    end

    context "with a polymorphic relationship" do
      setup do
        @review = Review.create(:reviewable => @user, :content => "troll")
      end

      should "include the associated object" do
        user_hash = Hash.from_xml(@user.to_xml(:with_reviews))
        assert_equal @review.content, user_hash["user"]["reviews"].first["content"]
      end

      should "serialize the associated object properly" do
        review_hash = Hash.from_xml(@review.to_xml)
        assert_equal @user.email, review_hash["review"]["reviewable"]["email"]
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

    context "serializing associated models" do
      setup do
        @user = User.create(:name => "John User", :email => "john@example.com")
        @check_in = @user.check_ins.create(:code_name => "Hello World")
      end

      should "find associations with multi-word names" do
        user_hash = ActiveSupport::JSON.decode(@user.to_json(:with_check_ins))['user']
        assert_equal @check_in.code_name, user_hash['check_ins'].first['code_name']
      end

      should "respect xml formatting options" do
        assert !@user.to_xml(:with_check_ins).include?('check-ins')
        assert !@user.to_xml(:with_check_ins).include?('type=')
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
    
  end
end
