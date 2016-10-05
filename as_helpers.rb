#!/usr/bin/env ruby

# ruby functions common to the utility scripts we use

require 'io/console'
require 'json'
require 'net/http'
require 'uri'

def get_token(params)
  unless params['token']
    print "login: "
    params['login'] = gets.chomp
    print "password: "
    params['password'] = STDIN.noecho(&:gets).chomp
    print "\n"
  end
  uri = URI("#{params['url']}/users/#{params['login']}/login")
  resp = Net::HTTP.post_form(uri, 'password' => params['password'])
  case resp.code
  when "200"
    return JSON.parse(resp.body)['session']
  else
    puts JSON.parse(resp.body)['error']
    get_token(params)
  end
end

def get_request(obj, params, opts = {})
  req = Net::HTTP::Get.new(obj)
  req.set_form_data(opts) unless opts.empty?
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(params['uri'].host, params['uri'].port) { |http| http.request(req) }
  case resp.code
  when "200"
    return resp
  when "412"
    error_code = JSON.parse(resp.body)['code'] rescue nil
    if error_code == "SESSION_EXPIRED" or error_code == "SESSION_GONE"
      puts "\nSession expired. Fetching new token... "
      params['token'] = get_token(params)
      get_request(obj, params, opts)
    end
  else
    puts "An error occurred: #{resp.message}"
  end
end

def post_request(obj, record, params, opts = {})
  req = Net::HTTP::Post.new(obj)
  req['X-ArchivesSpace-Session'] = params['token']
  req['Content-Type'] = opts[:content_type]
  req.body = record.to_json
  resp = Net::HTTP.start(params['uri'].host, params['uri'].port) { |http| http.request(req) }
  if resp.code == "200"
    return resp
  else
    puts "An error occurred: #{resp.message}"
  end
end

def get_data_model
  print "Select a data model:\n* (1) Resources\n* (2) Archival Objects\n* (3) Agents\n* (4) Subjects\n* (5) Digital Objects\n* (6) Accessions\n* (7) Top Containers\n> "
  data_model = gets.chomp.to_i
  case data_model
  when 1
    return "resources"
  when 2
    return "archival_objects"
  when 3
    return "agents"
  when 4
    return "subjects"
  when 5
    return "digital_objects"
  when 6
    return "accessions"
  when 7
    return "top_containers"
  else
    puts "Invalid entry, try again."
    get_data_model
  end
end

def get_report_type(data_model)
  puts "Select report type:"
  case data_model
  when "resources"
    print "* (1) Generic JSON\n* (2) EAD\n* (3) MARC\n> "
    type = gets.chomp.to_i
    case type
    when 1
      return "json"
    when 2
      return "ead"
    when 3
      return "marc"
    else
      puts "Invalid entry, try again."
      get_report_type(data_model)
    end
  when "agents"
    print "* (1) Generic JSON\n* (2) EAC-CPF\n> "
    type = gets.chomp.to_i
    case type
    when 1
      return "json"
    when 2
      return "eac"
    else
      puts "Invalid entry, try again."
      get_report_type(data_model)
    end
  else
    print "* (1) Generic JSON\n> "
    type = gets.chomp.to_i
    case type
    when 1
      return "json"
    else
      puts "Invalid entry, try again."
      get_report_type(data_model)
    end
  end
end

def run_report(type, data_model, params)
  request_url = case data_model
  when /subjects/, /^agents/
    "#{params['url']}/#{data_model}"
  else
    "#{params['url']}/#{params['repo']}/#{data_model}"
  end
  ids = JSON.parse(get_request(URI("#{request_url}"), params, { 'all_ids' => true }).body)
  data_model = data_model.gsub(/agents\//,'').gsub('software', 'softwares')

  case type

  # generic JSON output
  when "json"
    file_output = "#{params['path']}/json/#{data_model}_report.json"
    File.delete(file_output) if File.exist?(file_output)
    f = File.open(file_output, 'a')
    f.write("{\"#{data_model}\":[")
    ids.each_with_index do |id, i|
      print "Writing #{data_model} #{type} record #{i+1} of #{ids.length}... \r"
      resp = get_request(URI("#{request_url}/#{id}"), params)
      f.write(resp.body.chomp)
      f.write(",") unless i == ids.length - 1
    end
    f.write("]}")
    f.close unless f.nil?

  # Encoded Archival Context (EAC) output
  when "eac"
    url = "#{params['url']}/#{params['repo']}/archival_contexts/#{data_model}"
    ids.each_with_index do |id, i|
      print "Writing #{type} record #{i+1} of #{ids.length}... \r"
      file_output = "#{params['path']}/eac/#{data_model}_#{id}_eac.xml"
      File.delete(file_output) if File.exist?(file_output)
      resp = get_request(URI("#{request_url}/#{id}.xml"), params)
      File.open(file_output, 'w') { |f| f.write resp.body }
    end

  # MARCXML output
  when "marc"
    url = "#{params['url']}/#{params['repo']}/#{data_model}/marc21"
    ids.each_with_index do |id, i|
      print "Writing #{type} record #{i+1} of #{ids.length}... \r"
      resp = get_record(uri, URI("#{params['url']}/#{config['repo']}/#{data_model}/#{id}"), params)
      num = JSON.parse(resp.body)['id_0'].downcase
      file_output = "#{params['path']}/marc/#{num}_marc.xml"
      File.delete(file_output) if File.exist?(file_output)
      resp = get_request(URI("#{url}/#{id}.xml"), params)
      File.open(file_output, 'w') { |f| f.write resp.body }
    end

  # Encoded Archival Description output
  when "ead"
    url = "#{params['url']}/#{params['repo']}/resource_descriptions"
    ids.each_with_index do |id, i|
      print "Writing #{type} record #{i+1} of #{ids.length}... \r"
      file_output = "#{params['path']}/ead/#{id}_ead.xml"
      File.delete(file_output) if File.exist?(file_output)
      resp = get_request(URI("#{url}/#{id}.xml"), params)
      File.open(file_output, 'w') { |f| f.write resp.body }
    end
  end

  puts "\nDone."
end
