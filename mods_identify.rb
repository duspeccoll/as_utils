#!/usr/bin/env ruby

# script to get handle/local ID pairs for Islandora objects in Islandora

# It will either parse a provided XML or download one when given a Fedora
# handle, get the local identifier using Nokogiri, then write the pair to
# standard output (could also be a file if desired).

require 'nokogiri'
require 'open-uri'

if ARGV.empty?
  puts "Usage: mods_identify.rb [input]"
else
  ARGV.each do |input|
    if File.exist?(input)
      xml = File.open(input) {|f| Nokogiri::XML(f)}
    else
      xml = Nokogiri::XML(open("http://specialcollections.du.edu/islandora/object/codu:#{input}/datastream/MODS/view"))
    end
    xml.remove_namespaces!
    codu = input.gsub(/.+\//,"").gsub(/\.xml/,"")
    codu = "codu:#{codu}" unless codu.start_with?("codu:")
    identifier = xml.xpath("//identifier[@type='local']/text()")
    puts "#{codu}\t#{identifier}"
  end
end
