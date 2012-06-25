# models
require 'bcrypt'

DataMapper.setup(:default, 'sqlite:///Users/JonathanCutrell/Sites/ribbit/ribbit.db')
# include MD5 gem, should be part of standard ruby install

class User
  include DataMapper::Resource

  property :id,         Serial    # An auto-increment integer key
  property :username,      String, :length => 3..18    # A varchar type string, for short strings
  property :bio,       Text, :length => 0..500
  property :phash,		String, :length => 120 # password hash
  property :salt,		String # pass salt
  property :created_at, DateTime #signup date
  property :email, String # User's email
  property :gravatar, String, :length => 120 # User's gravatar based on email
  property :is_private, Boolean, :default => false

  validates_uniqueness_of :email, :message => "There's already a user with that email address."
  validates_uniqueness_of :username, :message => "That username has already been taken."
  validates_presence_of :username, :message => "You must enter a username."
  validates_presence_of :email, :message => "You must enter an email."
  validates_presence_of :phash, :message => "Did you forget to enter a password?"

  has n, :ribbits
  has n, :followed_users
  has n, :follows, 'User', :through => :followed_users
  has n, :users_followed, 'FollowedUser', :child_key => [ :follow_id ]
  has n, :followed_by,    'User', :through => :users_followed, :via => :user

  def is_private?
    return self.is_private
  end

end

class FollowedUser
  include DataMapper::Resource

  property :user_id,   Integer, :key => true
  property :follow_id, Integer, :key => true

  belongs_to :user
  belongs_to :follow, 'User'
end

class Ribbit
	include DataMapper::Resource

  property :id, Serial
  property :text, Text, :length => 1..140
  property :created_at, DateTime

  belongs_to :user
  def self.from_users_followed_by(user)
      Ribbit.all(:order => :created_at.desc, :user_id => user.follows.map(&:id)) + Ribbit.all(:user_id => user.id, :order=> :created_at.desc)
  end
end

DataMapper.auto_upgrade!