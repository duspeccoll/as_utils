#!/usr/bin/env ruby

require 'date'
require 'json'
require 'nokogiri'
require_relative 'as_helpers'

params = {
  'url' => "http://localhost:8089/",
  'repo_url' => "http://localhost:8089/repositories/2/",
  'marc' => "marc_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}.xml",
  'last_export' => (DateTime.now-7).to_time.to_i
}

params['token'] = get_token(params)

ids = JSON.parse(get_request(URI("#{params['repo_url']}resources"), params, {
  'all_ids' => true,
  'modified_since' => params['last_export']
  }).body)

builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') { |xml|
  xml.collection('xmlns' => "http://www.loc.gov/MARC21/slim", 'xmlns:marc' => "http://www.loc.gov/MARC21/slim")
}
doc = Nokogiri::XML(builder.to_xml)

ids.each do |id|
  marc = Nokogiri::XML(get_request(URI("#{params['repo_url']}resources/marc21/#{id}.xml"), params).body).remove_namespaces!
  doc.root << marc.root.children
end

File.open(params['marc'], 'w') { |f| f.write(doc.to_xml) }
