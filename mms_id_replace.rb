#!/usr/bin/env ruby

## a little thing that flips our Sierra bib record IDs to Alma MMS IDs
## so we can overlay ArchivesSpace updates through our import profile

require 'io/console'
require 'json'
require 'net/http'
require 'uri'
require 'nokogiri'

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

doc = Nokogiri::XML(File.open('ms_bibs.xml'))
records = doc.xpath("//collection//record")
records.each do |record|
  ids = record.xpath("datafield[@tag='099'][@ind2='9']/subfield[@code='a']")
  id = String.new
  unless ids.empty?
    ids.each_with_index do |x, i|
      id << x.text.strip
      id << " " unless i == ids.size - 1
    end
    id = id.gsub('MS ','')
    mms_id = record.xpath("controlfield[@tag='001']/text()")
    url = String.new
    File.foreach('resources.txt') do |resource|
      row = resource.chomp.split(/\t/)
      url = row[0] if row[1] == id
    end

    unless url == ''
      req = Net::HTTP::Get.new(URI("#{params['url']}#{url}"))
      req['X-ArchivesSpace-Session'] = params['token']
      resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      resource = JSON.parse(resp.body) if resp.code == '200'

      if resource['user_defined'].nil?
        resource['user_defined'] = {
          'jsonmodel_type' => 'user_defined',
          'string_2' => mms_id
        }
      else
        resource['user_defined']['string_2'] = mms_id
      end

      req = Net::HTTP::Post.new(URI("#{params['url']}#{url}"))
      req['Content-Type'] = 'application/json'
      req['X-ArchivesSpace-Session'] = params['token']
      req.body = resource.to_json
      resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      if resp.code == "200"
        puts "Success: #{id} (#{url})"
      else
        puts "Error: #{id} (#{url})"
      end
    end
  end
end
