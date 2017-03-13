#!/usr/bin/env ruby

require 'nokogiri'

# tell the script what file you want
print "File: "
mods_file = gets.chomp

# script reads the file
doc = Nokogiri::XML(File.open(mods_file))

# script creates one new MODS record per mods:mods in the mods:collection
doc.xpath('//mods:mods').each do |mods|
  filename = "#{mods.xpath('mods:identifier[@type="local"]').text}.xml"
  File.delete(filename) if File.exist?(filename)

  newdoc = Nokogiri::XML(mods.to_xml, nil, 'UTF-8')
  newdoc.root.add_namespace('mods',"http://www.loc.gov/mods/v3 http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/mods-3-6.xsd")
  
  File.open(filename, 'w') {|f| f.write newdoc}
end
