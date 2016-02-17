# We wrote a replace script because we needed to make a bunch of post-migration
# edits that aren't possible through the Batch Find/Replace Beta right now.

require 'io/console'
require 'json'
require 'net/http'
require 'uri'

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

def get_file
  print "name of file: "
  filename = gets.chomp
  unless File.exist?(file)
    print "File does not exist."
    filename = get_file
  end
  return filename
end

params = {}

params['url'] = "http://localhost:8089" # change this to whatever your AS backend URL is
(params['login'], params['password']) = aspace_login
params['token'] = get_token(params)

# the file should be a list of IDs associated with the ArchivesSpace data model that we can download and work with
filename = get_file

File.open(filename).each do |id|
  # get the backend URI and the link to the item
  uri = URI("#{params['url']}")
  object = URI("#{params['url']}/repositories/2/archival_objects/#{id.chomp.to_s}")

  # download the archival object from the backend
  req = Net::HTTP::Get.new(object)
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  record = JSON.parse(resp.body)

  # code below this comment parses the JSON and does whatever work you need to do on it

  # post the new JSON back through the backend
  req = Net::HTTP::Post.new(object)
  req['X-ArchivesSpace-Session'] = params['token']
  req['Content-Type'] = "application/json"
  req.body = record.to_json
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

  # puts whether the process succeeded or not
  if resp.code == "200"
    puts "Success: archival_objects/#{id.chomp.to_s}"
  else
    puts "Error: archival_objects/#{id.chomp.to_s}"
  end
end
