#!/usr/bin/env ruby
# remove instances from user-provided archival objects

require 'io/console'
require 'json'
require 'net/http'
require 'uri'

def remove_instance(params)
  print "Enter first ID (or 'exit' to exit): "
  id_first = gets.chomp
  exit if id_first == 'exit'
  print "Enter last ID (leave empty for single ID): "
  id_last = gets.chomp

  if id_last.empty?
    do_remove_instance("/repositories/2/archival_objects/#{id_first}", params)
  else
    if id_last < id_first
      puts "Error: Last ID can't be lower than first ID"
      exit
    end
    (id_first..id_last).each do |id|
      do_remove_instance("/repositories/2/archival_objects/#{id}", params)
    end
  end

  remove_instance(params)
end

def do_remove_instance(archival_object, params)
  # get the archival object
  uri = URI("#{params['url']}")
  obj = URI("#{params['url']}#{archival_object}")
  req = Net::HTTP::Get.new(obj)
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  json = JSON.parse(resp.body)

  # delete all of its instances
  json['instances'] = []

  # repost the revised archival object
  req = Net::HTTP::Post.new(obj)
  req['X-ArchivesSpace-Session'] = params['token']
  req['Content-Type'] = "application/json"
  req.body = json.to_json
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  if resp.code == "200"
    puts "Success: #{obj}"
  else
    puts "Error: #{obj}"
  end
end

def get_token(params)
  uri = URI("#{params['url']}/users/#{params['login']}/login")
  resp = Net::HTTP.post_form(uri, 'password' => params['password'])
  case resp.code
  when "200"
    return JSON.parse(resp.body)['session']
  else
    puts JSON.parse(resp.body)['error']
    (params['login'], params['password']) = aspace_login
    get_token(params)
  end
end

def aspace_login
  print "login: "
  login = gets.chomp
  print "password: "
  password = STDIN.noecho(&:gets).chomp
  print "\n"
  return login, password
end

params = { 'url' => "http://localhost:8089" }
(params['login'], params['password']) = aspace_login
params['token'] = get_token(params)

remove_instance(params)
