#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require_relative 'astools'

def item_from_results(results, id)
  results.each do |result|
    json = JSON.parse(result['json'])
    return result['uri'] if json['component_id'] == id
  end
end

def check_external_docs(item, codu)
  json = ASTools::HTTP.get_json(item)
  link = "http://hdl.handle.net/10176/#{codu}"
  docs = json['external_documents'].select{|x| x['title'] == "Special Collections @ DU"}
  if docs.length > 0
    unless docs[0]['location'].end_with?(codu)
      @log.puts "Updating link on item for #{codu}"
      json['external_documents'].each do |doc|
        doc['location'] = link if doc['title'] == "Special Collections @ DU"
      end
      ASTools::HTTP.post_json(item, json)
    end
  else
    @log.puts "Adding link to item for #{codu}"
    doc = {
      'title' => "Special Collections @ DU",
      'location' => link,
      'jsonmodel_type' => "external_document"
    }
    json['external_documents'].push(doc)
    ASTools::HTTP.post_json(item, json)
  end
end

def check_digital_objects(item, codu)
  json = ASTools::HTTP.get_json(item)
  link = "http://hdl.handle.net/10176/#{codu}"
  objects = json['instances'].select{|x| x['instance_type'] == "digital_object"}
  if objects.length > 0
    # this is sort of hacky but we haven't fully implemented is_representative? yet
    object_uri = objects[0]['digital_object']['ref']
    object = ASTools::HTTP.get_json(object_uri)
    unless object['digital_object_id'].end_with?(codu)
      @log.puts "Updating digital object link for #{codu}"
      object['digital_object_id'] = link
      ASTools::HTTP.post_json(object_uri, object)
    end
  else
    @log.puts "Creating new digital object for #{codu}"

    # first we create the new digital object...
    object = {
      'title' => json['title'],
      'digital_object_id' => link,
      'publish' => true,
      'jsonmodel_type' => "digital_object"
    }
    response = ASTools::HTTP.post_json("#{@repo}/digital_objects", object)

    # ...then we link the digital object to the item record
    object_uri = JSON.parse(response.body)['uri']
    item_json = ASTools::HTTP.get_json(item)
    object_ref = {
      'jsonmodel_type' => "instance",
      'instance_type' => "digital_object",
      'digital_object' => {'ref' => object_uri},
      'is_representative' => true
    }
    item_json['instances'].push(object_ref)
    ASTools::HTTP.post_json(item, item_json)
  end
end

# initialize variables
@repo = "/repositories/2"
logfile = "logfile.txt"
filename = ARGV[0]
ARGV.clear

# initialize a session
ASTools::User.get_session

if filename.nil?
  print "filename: "
  filename = gets.chomp
end
File.delete(logfile) if File.exist?(logfile)

begin
  @log = File.open(logfile, 'a')
  if File.exist?(filename)
    File.readlines(filename).each do |codu|
      codu = codu.chomp
      codu = "codu:#{codu}" unless codu.start_with?("codu:")
      xml = Nokogiri::XML(open("http://specialcollections.du.edu/islandora/object/#{codu}/datastream/MODS/view"))
      xml.remove_namespaces!
      id = xml.xpath("//identifier[@type='local']").text

      # set up our parameters to search
      search_params = {
        'q' => id,
        'filter_term[]' => "{\"primary_type\":\"archival_object\"}",
        'page' => "1"
      }

      results = ASTools::HTTP.get_json("#{@repo}/search", search_params)['results']
      item = item_from_results(results, id)
      if item.nil? || item.empty?
        @log.puts "Couldn't find an item for #{codu}"
      else
        check_external_docs(item, codu)
        check_digital_objects(item, codu)
      end
    end
  else
    puts "File not found: #{filename}"
  end
ensure
  @log.close
end
