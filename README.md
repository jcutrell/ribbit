# Ribbit
The goal of Ribbit is to show users how to use Sinatra (and other languages, in the series on NetTuts) fundamental ways to create an app like Twitter. There is following functionality, private functionality, and a bunch of other cool things going on.

===

If you take a look at the ribbit.rb file (the app file), you can see a few dependencies.

	require 'rubygems'
	require 'sinatra'
	require 'sinatra/flash'
	require 'data_mapper'
	require File.dirname(__FILE__) + '/models.rb'
	require 'digest/md5'

And in the models.rb file:

	require 'bcrypt'


## TODO:
- Add support for Pony for emailing
- Test all views
- Check for paths for all features; Complete contextuality.