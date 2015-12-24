require 'yaml'
require 'io/console'
require 'net/http'
require 'uri'
require 'json'

def get_record(uri, get_uri, params)
  req = Net::HTTP::Get.new(get_uri)
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  error_code = JSON.parse(resp.body)['code'] rescue nil
  if error_code == "SESSION_EXPIRED" or error_code == "SESSION_GONE"
    puts "\nSession expired. Fetching new token... "
    params['token'] = get_token(params)
    get_record(uri, get_uri, params)
  else
    return resp
  end
end

def run_report(type, data_model, params)
  config = YAML.load_file('config.yml')
  case data_model
  when /subjects/, /^agents/
    uri = URI("#{params['url']}/#{data_model}?all_ids=true")
    ids = Net::HTTP.get_response(uri)
  else
    uri = URI("#{params['url']}/#{config['repo']}/#{data_model}?all_ids=true")
    req = Net::HTTP::Get.new(uri)
    req['X-ArchivesSpace-Session'] = params['token']
    http = Net::HTTP.new(uri.host, uri.port)
    ids = http.request(req)
  end

  if ids.code == "404"
    puts ids.message
  else
    ids = JSON.parse(ids.body)
    case type
    # generic JSON output
    # the generic JSON output writes to a single file per data model; all others output indiv. records
    when "json"
      case data_model
      when /subjects/, /^agents/
        url = "#{params['url']}/#{data_model}"
      else
        url = "#{params['url']}/#{config['repo']}/#{data_model}"
      end
      data_model = data_model.gsub(/agents\//,'')
      file_output = "#{config['file_path']}/json/#{data_model}_report.json"
      File.delete(file_output) if File.exist?(file_output)
      File.open(file_output, 'w') { |f| f.write "{\"#{data_model}\":\[" }
      ids.each_with_index do |id, i|
        print "Writing #{type} record #{i+1} of #{ids.length} to #{file_output}... \r"
        resp = get_record(uri, URI("#{url}/#{id}"), params)
        File.open(file_output, 'a') { |f| f.write resp.body.chomp }
        File.open(file_output, 'a') { |f| f.write "," } if i < ids.length-1
      end
      File.open(file_output, 'a') { |f| f.write "\]}" }
    # Encoded Archival Context (EAC) output
    when "eac"
      data_model = data_model.gsub(/agents\//,'').gsub('software', 'softwares')
      url = "#{params['url']}/#{config['repo']}/archival_contexts/#{data_model}"
      ids.each do |id|
        print "Writing #{type} record #{i+1} of #{ids.length}... \r"
        file_output = "#{config['file_path']}/eac/#{data_model}_#{id}_eac.xml"
        File.delete(file_output) if File.exist?(file_output)
        resp = get_record(uri, URI("#{url}/#{id}.xml"), params)
        File.open(file_output, 'w') { |f| f.write resp.body }
      end
    # MARCXML output
    when "marc"
      url = "#{params['url']}/#{config['repo']}/#{data_model}/marc21"
      ids.each_with_index do |id, i|
        print "Writing #{type} record #{i+1} of #{ids.length}... \r"
        resp = get_record(uri, URI("#{params['url']}/#{config['repo']}/#{data_model}/#{id}"), params)
        num = JSON.parse(resp.body)['id_0'].downcase
        file_output = "#{config['file_path']}/marc/#{num}_marc.xml"
        File.delete(file_output) if File.exist?(file_output)
        resp = get_record(uri, URI("#{url}/#{id}.xml"), params)
        File.open(file_output, 'w') { |f| f.write resp.body }
      end
    # MODS output for digital objects
    when "mods"
      url = "#{params['url']}/#{config['repo']}/#{data_model}/mods"
      ids.each_with_index do |id, i|
        print "Writing #{type} record #{i+1} of #{ids.length}... \r"
        file_output = "#{config['file_path']}/mods/#{id}_mods.xml"
        File.delete(file_output) if File.exist?(file_output)
        resp = get_record(uri, URI("#{url}/#{id}.xml"), params)
        File.open(file_output, 'w') { |f| f.write resp.body }
      end
    # Encoded Archival Description output
    when "ead"
      url = "#{params['url']}/#{config['repo']}/resource_descriptions"
      ids.each_with_index do |id, i|
        print "Writing #{type} record #{i+1} of #{ids.length}... \r"
        file_output = "#{config['file_path']}/ead/#{id}_ead.xml"
        File.delete(file_output) if File.exist?(file_output)
        resp = get_record(uri, URI("#{url}/#{id}.xml"), params)
        File.open(file_output, 'w') { |f| f.write resp.body }
      end
    end
  end

  puts "\nDone."
end

def get_token(params)
  uri = URI("#{params['url']}/users/#{params['login']}/login")
  resp = Net::HTTP.post_form(uri, 'password' => params['password'])
  case resp.code
  when "200"
    return JSON.parse(resp.body)['session']
  else
    puts JSON.parse(resp.body)['error']
    (params['login'], params['password']) = aspace_login
    get_token(params)
  end
end

def aspace_login
  print "login: "
  login = gets.chomp
  print "password: "
  password = STDIN.noecho(&:gets).chomp
  print "\n"
  return login, password
end

def select_data_model
  print "Select a data model:\n* (1) Resources\n* (2) Archival Objects\n* (3) Agents\n* (4) Subjects\n* (5) Digital Objects\n> "
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
  else
    puts "Invalid entry, try again."
    select_data_model
  end
end

def select_report(data_model)
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
      select_report(data_model)
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
      select_report(data_model)
    end
  when "digital_objects"
    print "* (1) Generic JSON\n* (2) MODS\n> "
    type = gets.chomp.to_i
    case type
    when 1
      return "json"
    when 2
      return "mods"
    else
      puts "Invalid entry, try again."
      select_report(data_model)
    end
  else
    print "* (1) Generic JSON\n> "
    type = gets.chomp.to_i
    case type
    when 1
      return "json"
    else
      puts "Invalid entry, try again."
      select_report(data_model)
    end
  end
end

config = YAML.load_file('config.yml')
params = {}

params['url'] = config['url']
(params['login'], params['password']) = aspace_login
params['token'] = get_token(params)

data_model = select_data_model
type = select_report(data_model)

if data_model == "agents"
  run_report(type, "#{data_model}/people", params)
  run_report(type, "#{data_model}/corporate_entities", params)
  run_report(type, "#{data_model}/families", params)
  run_report(type, "#{data_model}/software", params)
else
  run_report(type, data_model, params)
end
