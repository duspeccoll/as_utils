#!/usr/bin/env ruby

require 'json'
require 'nokogiri'
require_relative 'astools'

def get_child_mods(child)
  filename = ""
  if child['component_id']
    filename << "#{@path}/#{child['component_id']}.xml"
  else
    filename << "#{@path}/#{child['id']}.xml"
  end
  if child['level'] == "item"
    mods = Nokogiri::XML(ASTools::HTTP.get_data("#{@repo}/archival_objects/mods/#{child['id']}.xml"))
    File.delete(filename) if File.exist?(filename)
    File.open(filename, 'w') { |f| f.write(mods.to_xml) }
  end
  child['children'].each do |child|
    get_child_mods(child)
  end
end

@repo = "/repositories/2"

ASTools::User.get_session

print "resource id: "
id = gets.chomp
@path = "/home/kevin/mods_#{id}"
Dir.mkdir(@path) unless Dir.exist?(@path)

json = ASTools::HTTP.get_json("#{@repo}/resources/#{id}/tree")
json['children'].each do |child|
  get_child_mods(child)
end
