require 'rubygems'
require 'sinatra'
require 'sinatra/flash'
require 'data_mapper'
require File.dirname(__FILE__) + '/models.rb'
require 'digest/md5'
require 'pony'

Pony.options = {
  :via => :smtp,
  :via_options => {
    :address => 'smtp.sendgrid.net',
    :port => '587',
    :domain => 'heroku.com',
    :user_name => ENV['SENDGRID_USERNAME'],
    :password => ENV['SENDGRID_PASSWORD'],
    :authentication => :plain,
    :enable_starttls_auto => true
  }
}


enable :sessions

helpers do
	def logged_in?
		if session[:username].nil?
			return false
		else
			return true
		end
	end
	def authenticate!
		if !logged_in?
			flash[:warning] = "You must be logged in to do that!"
			redirect '/'
		end
	end
	def current_user
		if logged_in?
			User.first(:username => session[:username].downcase)
		else
			"Guest"
		end
	end
	def current_user_name
		if logged_in?
			@username = current_user.username
		else
			@username = current_user
		end
	end
end

### LOGIN

get '/login' do
	erb :login, :layout => :layout
end

post '/login' do
  u = params[:username].downcase
  acct = User.first(:username => u)
  if acct.nil?
  	flash[:error] = "Your username and/or password was incorrect."
	redirect '/login'
  else
  	if acct.phash == BCrypt::Engine.hash_secret(params[:password], acct.salt)
	  	session[:username] = params[:username].downcase
	  	flash[:notice] = "Welcome back, #{params[:username]}!"
	  	redirect '/welcome'
	  else
	  	flash[:error] = "Your username and/or password was incorrect."
	  	redirect '/login'
	  end
  end
end

get '/logout' do
	session.clear
	redirect '/'
end


get '/' do
	@title = "Ribbit"
	if logged_in?
		@followed_ribbits = Ribbit.from_users_followed_by(current_user)
	end
	@public_users = User.all(:is_private => false)
	erb :home, :layout => :layout
end



### SHOW ALL PUBLIC RIBBITS

['/ribbits', '/public'].each do |path|
	get path do
		authenticate!
		@ribbits = Ribbit.all(Ribbit.user.is_private => false, :order => :created_at.desc) + current_user.ribbits(:order => :created_at.desc)
		erb :'ribbits/public', :layout => :layout
	end
end



get '/welcome' do
	authenticate!
	@followed_ribbits = Ribbit.from_users_followed_by(current_user)
	erb :welcome, :layout => :layout
end

['/users', '/users/all', '/users/index'].each do | path |
	get path do
		# get all registered users
		@users = User.all(:is_private => false) + current_user.follows
		erb :'users/index', :layout => :layout
	end
end
get "/users/new" do
	if logged_in?
		flash[:warning] = "You can't create another user when you're still logged in."
		redirect '/' # can't create a new user while you're still logged in.
	else
		erb :'users/new', :layout => :layout
	end
end
get "/following" do
	authenticate!
	@users = current_user.follows
	erb :'users/index', :layout => :layout
end
get "/followers" do
	authenticate!
	@users = current_user.followed_by
	erb :'users/index', :layout => :layout
end

post "/users/create" do
	# new user
	params["salt"] = BCrypt::Engine.generate_salt
 	params["phash"] = BCrypt::Engine.hash_secret(params[:password], params[:salt])
 	email_hash = Digest::MD5.hexdigest(params[:email].downcase)
 	params["gravatar"] = "http://www.gravatar.com/avatar/#{email_hash}"
 	props = Hash[params.map{|k,v| [k.to_sym,v]}]
 	props[:username] = props[:username].downcase
	props[:email] = props[:email].downcase
	@username = props[:username]
	# Pony.mail(:to => props[:email], :from => "donotreply@herokuapp.com", :subject => 'Welcome to Ribbit!', :body => (erb :'/mail/welcome', :layout => false))
 	props.delete :password
 	props[:created_at] = Time.now
 	user = User.create(props)
 	STDERR.puts user.errors.inspect
 	if user.saved?
 		session[:username] = props[:username]
 		flash[:notice] = "Welcome, #{session[:username]}"
 		redirect '/welcome'
 	else
 		flash[:error] = "Something happened, and we couldn't create your account. Try again?"
 		puts "Not saved. Why???"
 		session[:username] = nil
 		redirect "/users/new"
 	end
end

### CREATE OR DELETE A RIBBIT
get '/ribbit/new' do
	authenticate!
	erb :'ribbits/new', :layout => :layout
end

post '/ribbit/create' do
  # todo: post a ribbit
  authenticate!
  props = params.clone
  props[:user_id] = current_user.id
  props[:created_at] = Time.now
  if Ribbit.create(props)
  	redirect "/"
  else
  	flash[:error] = "Something happened, and we couldn't create your ribbit. Try again."
  	redirect "/ribbit/new"
  end
end

delete '/ribbit/:id/delete' do
	authenticate!
	# get the ribbit
	ribbit = Ribbit.first(:id => params[:id])
	# delete ribbit if logged in and belongs to user
	if ribbit.user.id == current_user.id
		if ribbit.destroy
			flash[:notice] = "Ribbit successfully deleted"
			redirect "/"
		else
			flash[:error] = "Ribbit wasn't deleted for whatever reason. Try again."
			redirect "/ribbit/#{params[:id]}"
		end
	else
		flash[:error] = "You can't delete a ribbit unless it is yours."
		redirect "/"
	end
end

### SHOW A RIBBIT

get '/ribbit/:id' do
	authenticate!
	# get ribbit by its id and show it
	@ribbit = Ribbit.get(params[:id])
	if @ribbit.user.is_private && !@ribbit.user.follows(:id => current_user.id)
		flash[:error]  = "Can't view that ribbit - that user is private and doesn't follow you."
		redirect '/'
	else
		erb :'ribbit/show'
	end
end

## Account delete

post '/user/:id/delete' do
	authenticate!
	userid = params[:id]
	if current_user.id == userid
		u = User.get(current_user.id)
		relationships = FollowedUser.all(:user_id => u.id) + FollowedUser.all(:follow_id => u.id)
		relationships.destroy
		u.destroy
		session.clear
		flash[:notice] = "You have successfully deleted your account."
		redirect '/'
	else
		flash[:error] = "You can't delete someone else's account."
		redirect '/'
	end
end
get '/:username/edit' do
	authenticate!
	@user = User.first(:username => params[:username])
	if @user.id == current_user.id
		erb :'users/edit', :layout => :layout
	else
		flash[:warning] = "You can't edit someone else's profile."
		redirect '/'
	end
end
put '/:user/update' do
	authenticate!
	props = Hash[params.map{|k,v| [k.to_sym,v]}]
	user = User.first(:username => props[:user])
	props.delete :user
	props.delete :_method
	props.delete :splat
	props.delete :captures
	props.delete :captures
	if user.id == current_user.id
		if user.update(props)
			flash[:notice] = "Profile successfully updated."
			redirect "/#{props[:username]}"
		else
			flash[:error] = "Something went wrong - try again."
			redirect "/#{params["user"]}/edit"
		end
	else
		flash[:warning] = "You can't update someone else's profile."
		redirect '/'
	end
end
['/:username', '/users/:username'].each do | path |
	get path do
		authenticate!
		puts params[:username]
		@selected_user = User.first(:username => params[:username])
		if @selected_user.is_private && !@selected_user.follows(:id => current_user.id)
			flash[:warning] = "That user's account is private, and can only be viewed by people they follow."
			redirect '/'
		end
		@is_followed = FollowedUser.first(:user_id => current_user.id, :follow_id => @selected_user.id)
		erb :'users/show', :layout => :layout
	end
end

['/:username/follow', '/users/:username/follow'].each do | path |
	get path do
		authenticate!
		follow_user = User.first(:username => params[:username])
		follow_id = follow_user.id
		follow = FollowedUser.new(:user_id => current_user.id, :follow_id => follow_id)
		puts follow_id
		puts current_user.id
		puts session[:username]
		if follow.save
			flash[:notice] = "You're now following #{params[:username]}"
			redirect "/#{params[:username]}"
		else
			flash[:error] = "Could not follow #{params[:username]} - try again."
			redirect "/#{params[:username]}"
		end
	end
end
['/:username/unfollow', '/users/:username/unfollow'].each do | path |
	get path do
		authenticate!
		followed_user = User.first(:username => params[:username])
		follow_id = followed_user.id
		follow = FollowedUser.first(:follow_id => follow_id, :user_id => current_user.id)
		if follow.destroy
			flash[:notice] = "Unfollowed #{params[:username]}"
			redirect "/"
		else
			flash[:error] = "Could not unfollow #{params[:username]} - try again."
			redirect "/#{params[:username]}"
		end
	end
end

not_found do
	halt 404, 'page not found'
end

