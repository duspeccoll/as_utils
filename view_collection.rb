#!/usr/bin/env ruby

# view all children of the provided Islandora PID (useful for evaluating collection contents + metadata)
# Keith Tarrant (Digitization Coordinator) originally wrote this in Python
# Kevin Clair (Metadata and Digitization Librarian) ported it to Ruby to integrate it with other ArchivesSpace utilities

require 'net/http'
require 'nokogiri'
require_relative 'astools'

@repo = "/repositories/2"
solr_url = "" # set this to whatever your Solr URL is
log = "view_collection_log.txt"

def get_request(url)
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  response = Net::HTTP.start(uri.host, uri.port) {|http| http.request(req)}

  response
end

def check_identifier(item)
  url = "http://specialcollections.du.edu/islandora/object/#{item}"
  resp = get_request("#{url}/datastream/MODS/view")
  if resp.is_a?(Net::HTTPSuccess) || resp.code == "200"
    xml = Nokogiri::XML(resp.body)
    xml.remove_namespaces!
    id = xml.xpath("//identifier[@type='local']").text
    return nil if id.empty?

    id
  else
    nil
  end
end

def items_for_pid(pid)
  items = []
  resp = get_request("#{solr_url}/collection1/select?q=RELS_EXT_isMemberOfCollection_uri_ms%3A%22info%3Afedora%2Fcodu%3A#{pid}%22&rows=500&wt=xml&indent=true")
  if resp.is_a?(Net::HTTPSuccess) || resp.code == "200"
    xml = Nokogiri::XML(resp.body)
    results = xml.xpath("//response//result[@name='response']//doc")
    results.each{|result| items.push(result.xpath("str[@name='PID']").text)}
    return items
  else
    nil
  end
end

pid = ARGV.shift
ARGV.clear
if pid.empty?
  print "PID: "
  pid = gets.chomp
end

items = items_for_pid(pid)
if items.nil?
  puts "Uh oh, collection at codu:#{pid} has no objects"
else
  items.each do |item| 
    id = check_identifier(item)
    puts "#{item}\t#{id}"
  end
end
