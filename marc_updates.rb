#!/usr/bin/env ruby

require 'date'
require 'json'
require 'nokogiri'
require 'io/console'
require 'uri'
require 'net/http'

@url = "http://localhost:8089"

def get_token(url)
  print "login: "
  login = gets.chomp
  print "password: "
  pwd = STDIN.noecho(&:gets).chomp
  print "\n"
  uri = URI("#{url}/users/#{login}/login")
  resp = Net::HTTP.post_form(uri, 'password' => pwd)
  case resp.code
  when "200"
    return JSON.parse(resp.body)['session']
  else
    puts JSON.parse(resp.body)['error']
    get_token
  end
end

def get_request(obj, token, opts = {})
  uri = URI("#{@url}")
  req = Net::HTTP::Get.new(obj)
  req.set_form_data(opts) unless opts.empty?
  req['X-ArchivesSpace-Session'] = token
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  case resp.code
  when "200"
    return resp
  when "412"
    error_code = JSON.parse(resp.body)['code'] rescue nil
    if error_code == "SESSION_EXPIRED" or error_code == "SESSION_GONE"
      puts "\nSession expired. Fetching new token... "
      token = get_token
      get_request(obj, token, opts)
    end
  else
    puts "An error occurred: #{resp.message}"
  end
end

token = get_token(@url)
print "How many days of updates?: "
days = gets.chomp

ids = JSON.parse(get_request(URI("#{@url}/repositories/2/resources"), token, {
  'all_ids' => true,
  'modified_since' => (DateTime.now-(days.to_i)).to_time.to_i
}).body)

builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') { |xml|
  xml.collection('xmlns' => "http://www.loc.gov/MARC21/slim", 'xmlns:marc' => "http://www.loc.gov/MARC21/slim")
}
doc = Nokogiri::XML(builder.to_xml)

ids.each do |id|
  marc = Nokogiri::XML(get_request(URI("#{@url}/repositories/2/resources/marc21/#{id}.xml"), token).body)
  marc.remove_namespaces!
  doc.root << marc.root.children
end

File.open("marc_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}.xml", 'w') { |f| f.write(doc.to_xml) }
