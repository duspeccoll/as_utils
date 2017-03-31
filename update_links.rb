#!/usr/bin/env ruby

# view all children of the provided Islandora PID (useful for evaluating collection contents + metadata)

require 'net/http'
require 'nokogiri'
require_relative 'astools'

@solr_url = "" # change this to the Solr URL for your Fedora repo
@repo = "/repositories/2"
log = "update_links_log.txt"

def get_request(url)
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  response = Net::HTTP.start(uri.host, uri.port) {|http| http.request(req)}

  response
end

def item_from_results(results, id)
  results.each do |result|
    json = JSON.parse(result['json'])
    return result['uri'] if json['component_id'] == id
  end
end

def check_external_docs(json, pid)
  uri = json['uri']
  link = "http://hdl.handle.net/10176/#{pid}"
  docs = json['external_documents'].select{|x| x['title'] == "Special Collections @ DU"}
  if docs.length > 0
    if docs[0]['location'].end_with?(pid)
      @f.puts "Link already updated for #{json['component_id']}"
    else
      @f.puts "Updating link on item for #{json['component_id']}"
      json['external_documents'].each do |doc|
        doc['location'] = link if doc['title'] == "Special Collections @ DU"
      end
      ASTools::HTTP.post_json(uri, json)
    end
  else
    @f.puts "Adding link to item for #{json['component_id']}"
    doc = {
      'title' => "Special Collections @ DU",
      'location' => link,
      'jsonmodel_type' => "external_document"
    }
    json['external_documents'].push(doc)
    ASTools::HTTP.post_json(uri, json)
  end
end

def check_digital_objects(json, pid)
  uri = json['uri']
  link = "http://hdl.handle.net/10176/#{pid}"
  objects = json['instances'].select{|x| x['instance_type'] == "digital_object"}
  if objects.length > 0
    # the is_representative? flag would make this easier but we haven't fully implemented it yet
    object_uri = objects[0]['digital_object']['ref']
    object = ASTools::HTTP.get_json(object_uri)
    if object['digital_object_id'].end_with?(pid)
      @f.puts "Digital object link already updated for #{json['component_id']}"
    else
      @f.puts "Updating digital object link for #{json['component_id']}"
      object['digital_object_id'] = link
      ASTools::HTTP.post_json(object_uri, object)
    end
  else
    @f.puts "Creating new digital object for #{json['component_id']}"

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
    item_json = ASTools::HTTP.get_json(uri)
    object_ref = {
      'jsonmodel_type' => "instance",
      'instance_type' => "digital_object",
      'digital_object' => {'ref' => object_uri},
      'is_representative' => true
    }
    item_json['instances'].push(object_ref)
    ASTools::HTTP.post_json(uri, item_json)
  end
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

def update_record(pid)
  id = check_identifier(pid)
  if id.nil?
    @f.puts "#{pid} has no identifier in its Islandora MODS record"
  else
    search_params = {
      'q' => id,
      'filter_term[]' => "{\"primary_type\":\"archival_object\"}",
      'page' => "1"
    }

    results = ASTools::HTTP.get_json("/repositories/2/search", search_params)['results']
    item = item_from_results(results, id)
    if item.nil? || item.empty?
      @f.puts "#{pid} has identifier (#{id}) in Islandora MODS but the record could not be found in ArchivesSpace"
    else
      json = ASTools::HTTP.get_json(item)
      if json['level'] == "item"
        check_external_docs(json, pid)
        check_digital_objects(json, pid)
      else
        @f.puts "#{pid} found in ArchivesSpace (#{json['component_id']}) but it's not an item record"
      end
    end
  end
end

def items_for_pid(pid)
  items = []
  resp = get_request("#{@solr_url}/collection1/select?q=RELS_EXT_isMemberOfCollection_uri_ms%3A%22info%3Afedora%2Fcodu%3A#{pid}%22&rows=500&wt=xml&indent=true")
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
if pid.nil?
  print "PID: "
  pid = gets.chomp
end

# initialize ArchivesSpace session
ASTools::User.get_session

File.delete(log) if File.exist?(log)
@f = File.open(log, 'a')

begin
  items = items_for_pid(pid)
  if items.nil?
    puts "Collection at codu:#{pid} has no objects"
  else
    items.each {|item| update_record(item)}
  end
ensure
  @f.close
end
