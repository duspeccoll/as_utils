#!/usr/bin/env ruby

require 'io/console'
require 'net/http'
require 'uri'
require 'json'
require_relative 'astools'

@repo = "/repositories/2"
@path = "/home/kevin"

data_model_opts = {
  '1' => "resources",
  '2' => "archival_objects",
  '3' => "agents",
  '4' => "subjects",
  '5' => "digital_objects",
  '6' => "accessions",
  '7' => "top_containers",
  '8' => "container_profiles"
}

agent_types = ["people", "corporate_entities", "families", "software"]

def selector(type, opts)
  puts "Select a #{type}:"
  opts.each do |k,v|
    puts "* (#{k}) #{v}"
  end

  opt = gets.chomp
  if opts.has_key?(opt)
    return opts[opt]
  else
    puts "Invalid entry, try again."
    selector(type, opts)
  end
end

def get_report_type(model)
  opts = case model
  when "resources"
    { '1' => "json", '2' => "ead", '3' => "marc" }
  when "agents"
    { '1' => "json", '2' => "eac" }
  else
    { '1' => "json" }
  end

  selector("report type", opts)
end

def write_single_file(filename, data)
  File.delete?(filename) if File.exist?(filename)
  File.open(filename, 'w') {|f| f.write data}
end

def run_report(type, model)
  request_url = case model
  when /subjects/, /^agents/, /container_profiles/
    "/#{model}"
  else
    "#{@repo}/#{model}"
  end
  ids = ASTools::HTTP.get_json(request_url, 'all_ids' => true)
  model = model.gsub(/agents\//,'').gsub('software', 'softwares')

  case type

  # generic JSON output
  when "json"
    file_output = "#{@path}/#{model}_report.json"
    File.delete(file_output) if File.exist?(file_output)
    f = File.open(file_output, 'a')
    f.write("{\"#{model}\":[")
    ids.each_with_index do |id, i|
      print "Writing #{model} #{type} record #{i+1} of #{ids.length}... \r"
      json = ASTools::HTTP.get_json("#{request_url}/#{id}")
      f.write(json.to_json)
      f.write(",") unless i == ids.length - 1
    end
    f.write("]}")
    f.close unless f.nil?

  # Encoded Archival Context (EAC) output
  when "eac"
    url = "#{@repo}/archival_contexts/#{model}"
    ids.each_with_index do |id, i|
      print "Writing #{type} record #{i+1} of #{ids.length}... \r"
      data = ASTools::HTTP.get_data("#{request_url}/#{id}.xml")
      write_single_file("#{@path}/eac/#{model}_#{id}_eac.xml", data)
    end

  # MARCXML output
  when "marc"
    ids.each_with_index do |id, i|
      print "Writing #{type} record #{i+1} of #{ids.length}... \r"
      num = ASTools::HTTP.get_json("/#{@repo}/#{model}/#{id}")['id_0'].downcase
      data = ASTools::HTTP.get_data("/#{@repo}/#{model}/marc21/#{id}.xml")
      write_single_file("#{@path}/marc/#{num}_marc.xml", data)
    end

  # Encoded Archival Description output
  when "ead"
    ids.each_with_index do |id, i|
      print "Writing #{type} record #{i+1} of #{ids.length}... \r"
      num = ASTools::HTTP.get_json("#{@repo}/resources/#{id}")['id_0'].downcase
      data = ASTools::HTTP.get_data("#{@repo}/resource_descriptions/#{id}.xml")
      write_single_file("#{@path}/ead/#{num}_ead.xml", data)
    end
  end

  puts "\nDone."
end

ASTools::User.get_session

model = selector("data model", data_model_opts)
type = get_report_type(model)

if model == "agents"
  agent_types.each do |atype|
    run_report(type, "#{model}/#{atype}")
  end
else
  run_report(type, model)
end
