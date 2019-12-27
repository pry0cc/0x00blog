#!/usr/bin/env ruby

require 'mechanize'
require 'json'
require 'sinatra'
require 'erb'

@agent = Mechanize.new()
data = {}
set :port, 8080
set :bind, '0.0.0.0'

t = Thread.new {
	while true do
		topics = get_group_user_topics("VIP")

		topics.each do |topic|
			year = topic["created_at"].split("-")[0]
			if !data.keys.include? year
				data[year] = []
				data[year].push(topic)
			else
				data[year].push(topic)
			end
		end

		puts "Sleeping #{1200 / 60} minutes."
		sleep 1200
	end
}

def get_group_users(group)
	return JSON.parse(@agent.get("https://0x00sec.org/g/#{group}/members.json").body())["members"]
end	

def get_user_topics(user)
	return JSON.parse(@agent.get("https://0x00sec.org/topics/created-by/#{user}.json").body())["topic_list"]["topics"]
end

def get_username_from_id(id)
	return JSON.parse(@agent.get("https://0x00sec.org/t/#{id}.json").body())["post_stream"]["posts"][0]["username"]

end

def get_group_user_topics(group)
	topics = []
	users = get_group_users(group)
	users.each do |user|
		username = user["username"]

		puts "Getting topics for #{username}"
		get_user_topics(username).each do |topic|
			id = topic["id"]
			topic["username"] = username
			if !topic["title"].include? "About the " and !topic["title"].include? " category"
				topics.push(topic)
			end
		end
	end
	topics.sort_by! { |topic| topic["created_at"] }
	topics.reverse!

	return topics
end

def select_fields(arr, fields)
	sorted_items = []
	arr.each do |item|
		item_hash = {}
		fields.each do |field|
			item_hash[field] = item[field]
		end
		sorted_items.push(item_hash)
	end

	return sorted_items
end

get '/api' do
	if params[:year]
		if data.length == 0
			return JSON.pretty_generate([{
				"username"=>"Cache is still being generated, please be patient while it loads :)",
				"views"=>"",
				"title"=>"",
				"created_at"=>""
			}])
		else
			if data.keys.include? params[:year]
				sorted_topics = data[params[:year]].select {|topic| topic["created_at"].split("-")[0] == params[:year]}
				
				JSON.pretty_generate(select_fields(sorted_topics, ["id", "title", "username", "views", "like_count", "created_at"]))
			else
				return "Year is invalid, you can only select the following year: #{data.keys.to_s}"
			end
		end
	else
		return "Year parameter is missing"
	end
end

get '/years' do
	return JSON.pretty_generate(data.keys().reverse)
end

get '/' do
	return File.open("templates/menu.erb", "r").read()
end

