#!/usr/bin/env ruby
require "mechanize"
require "json"
require "sinatra"
require "erb"
require "open-uri"


# Sinatra Settings (Don't reccomend to touch)
set(:port, 8080)
set(:bind, "0.0.0.0")
set(:public_folder, "public")

# Load templates once
post_template = File.open("templates/post.erb", "r").read
menu_template = File.open("templates/menu.erb", "r").read

# Default configs (Can be override with enviornment variables)
$username = ENV["USER"] ? ENV["USER"] : "pry0cc"
$group = ENV["GROUP"] ? ENV["GROUP"] : "VIP"
$theme = ENV["THEME"] ? ENV["THEME"] : "edgy"
$refresh_time = ENV["REFRESH"] ? ENV["REFRESH"] : 1200
$mode = ENV["MODE"] ? ENV["MODE"] : "user"

# Startup Messages
puts("Starting as in #{$mode} mode")

if $mode == "user"
  puts("Using username #{$username}")
elsif $mode == "group"
  puts("Using group #{$group}")
end

class OhSec
  attr_accessor :data, :topic_data, :topics

  def initialize(username, group)
    @agent = Mechanize.new
    @data = {}
    @topic_data = {}
    @topics = []
    @username = username
    @group = group
    self.update
  end

  def update
    t = Thread.new {
      while true

        if $mode == "group"
          @topics = get_group_user_topics(@group)
        elsif $mode == "user"
          @topics = get_all_user_topics(@username)
        end

        @data = {}


        @topics.each do |topic|
          year = topic["created_at"].split("-")[0]

          if !@data.keys.include?(year)
            @data[year] = []
            @data[year].push(topic)
          else
            @data[year].push(topic)
          end
        end

        puts("Sleeping #{$refresh_time / 60} minutes.")

        sleep($refresh_time)
      end
    }
  end

  def get_group_users(group)
    return JSON.parse(@agent.get("https://0x00sec.org/g/#{group}/members.json?limit=200").body)["members"]
  end

  def get_user_topics(user)
    topics = []
    last_topics = ["test"]
    i = 0
    while last_topics.length > 0

      if i == 0
        last_topics = JSON.parse(@agent.get("https://0x00sec.org/topics/created-by/#{user}.json").body)["topic_list"]["topics"]
      else
        last_topics = JSON.parse(@agent.get("https://0x00sec.org/topics/created-by/#{user}.json?page=#{i}").body)["topic_list"]["topics"]
      end

      last_topics.each do |topic|
        topics.push(topic)
      end

      i += 1
    end

    return topics
  end

  def get_topic_from_id(id)
    return JSON.parse(@agent.get("https://0x00sec.org/t/#{id}.json").body)
  end

  def get_username_from_id(id)
    return JSON.parse(@agent.get("https://0x00sec.org/t/#{id}.json").body)["post_stream"]["posts"][0]["username"]
  end

  def get_group_user_topics(group)
    topics = []
    users = self.get_group_users(group)

    users.each do |user|
      username = user["username"]
      puts("Getting topics for #{username}")

      self.get_user_topics(username).each do |topic|
        id = topic["id"]
        topic["username"] = username

        if !topic["title"].include?("About the ") and !topic["title"].include?(" category")
          topics.push(topic)
        end
      end
    end

             # @topic_data[id] = self.get_topic_from_id(id)
          # puts("Got #{id} for #{username}")
    topics.sort_by! { |topic| topic["created_at"] }
    topics.reverse!
    return topics
  end

  def get_all_user_topics(username)
    topics = []
    puts("Getting topics for #{username}")

    self.get_user_topics(username).each do |topic|
      id = topic["id"]
      topic["username"] = username

      if !topic["title"].include?("About the ") and !topic["title"].include?(" category")
        topics.push(topic)
      end
    end

        # @topic_data[id] = self.get_topic_from_id(id)
        # puts("Got #{id} for #{username}")
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
end

vip = OhSec.new($username, $group)

get("/api") do
  if params[:year]
    if vip.data.length == 0
      return JSON.pretty_generate([
        {"error" => "Cache is still being generated, please be patient while it loads :)"},
      ])
    else
      if vip.data.keys.include?(params[:year])
        sorted_topics = vip.data[params[:year]].select { |topic| topic["created_at"].split("-")[0] == params[:year] }
        JSON.pretty_generate(vip.select_fields(sorted_topics, [
          "id",
          "title",
          "username",
          "views",
          "like_count",
          "created_at",
        ]))
      else
        return "Year is invalid, you can only select the following year: #{vip.data.keys.to_s}"
      end
    end

  else
    return "Year parameter is missing"
  end
end

get("/t/:id/") do
  begin
    local_data = vip.topic_data[params[:id].to_i]["post_stream"]["posts"][0]
    $cooked = local_data["cooked"]
    $username = local_data["username"]
    $topic_slug = local_data["topic_slug"]
    $id = params[:id]
    result = ERB.new(post_template).result(binding)
  rescue Exception => e
    result = "404"
  end

  return result
end

get("/t/:id/flat") do
  begin
    local_data = vip.topic_data[params[:id].to_i]["post_stream"]["posts"][0]
    $cooked = local_data["cooked"]
    $username = local_data["username"]
    $topic_slug = local_data["topic_slug"]
    result = ERB.new(post_template).result(binding)
  rescue Exception => e
    return "404 #{e.to_s} #{e.backtrace}"
  else
    if File.exist?("saved/#{$topic_slug}.html")
      redirect("/#{$topic_slug}.html")
    else
      html = Nokogiri::HTML(result)
      images = html.css("img")
      for       image in images

        if image["src"][0..1] == "//"
          tmp = image["src"]
          image["src"] = "https:#{tmp}"
        end

        base64 = Base64.encode64(open(image["src"]).read)

        image["src"] = "data:image/jpg;base64," + base64
      end

      File.open("saved/#{$topic_slug}.html", "w") { |file| file.write(html.to_html) }
      redirect("/#{$topic_slug}.html")
    end
  end
end

get("/*.html") do
  file = params["splat"][0]

  if File.exist?(("saved/#{file}.html"))
    return File.open("saved/#{file}.html", "r").read
  end
end

get("/years") do
  return JSON.pretty_generate(vip.data.keys.reverse)
end

get("/") do
  return ERB.new(menu_template).result(binding)
end
