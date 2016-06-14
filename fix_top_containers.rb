#!/usr/bin/env ruby
## Add top containers with barcodes that already exist in the system to
## ArchivesSpace. For use in upgrading to v1.5.0.
##
## We had a few instances where a single barcode was linked to multiple
## archival objects (material from multiple series in a single box, etc.)
## The container migration tool in 1.5.0 only migrates one instance of a
## barcode successfully, so any other instances of a barcode were reported as
## errors in the migration job's CSV report.
##
## This script reads through that report for archival object URIs, links them
## to the appropriate top container based on the barcode, and re-uploads them
## to ArchivesSpace through the API.

require 'io/console'
require 'json'
require 'net/http'
require 'uri'

def get_filename
  print "filename: "
  filename = gets.chomp
  unless File.exist?(filename)
    puts "File #{filename} doesn't exist!"
    filename = get_filename
  end

  filename
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

params = {}

params['url'] = "http://localhost:8089" # change this to whatever your AS backend URL is
(params['login'], params['password']) = aspace_login
params['token'] = get_token(params)
uri = URI("#{params['url']}")
filename = get_filename

File.foreach(filename) do |line|
  line = line.chomp.split(',')
  box_url = line[0]
  barcode = line[1]

  req = Net::HTTP::Get.new(URI("#{params['url']}/repositories/2/top_containers/search?q=#{barcode}"))
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  results = JSON.parse(resp.body) if resp.code == "200"

  top_container = results['response']['docs'][0]['id']

  req = Net::HTTP::Get.new(URI("#{params['url']}#{box_url}"))
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  box = JSON.parse(resp.body) if resp.code == "200"

  box['instances'].each do |instance|
    if instance['container']['barcode_1'] == barcode
      instance['sub_container'] = {
        'jsonmodel_type' => "sub_container",
        'top_container' => {
          'ref' => top_container
        }
      }
    end
  end

  req = Net::HTTP::Post.new(URI("#{params['url']}#{box_url}"))
  req['Content-Type'] = "application/json"
  req['X-ArchivesSpace-Session'] = params['token']
  req.body = box.to_json
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  if resp.code == "200"
    puts "Success: #{box_url}"
  else
    puts "Error: #{box_url}"
  end
end
