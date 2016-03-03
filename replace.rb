# We wrote a replace script because we needed to make a bunch of post-migration
# edits that aren't possible through the Batch Find/Replace Beta right now.

# This one is set up to remove trailing periods from genre/form headings, a
# relic of our last collection management system.

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

params = {}

params['url'] = "http://localhost:8089" # change this to whatever your AS backend URL is
(params['login'], params['password']) = aspace_login
params['token'] = get_token(params)
uri = URI("#{params['url']}")

req = Net::HTTP::Get.new(URI("#{params['url']}/subjects"))
req.set_form_data('all_ids' => true)
req['X-ArchivesSpace-Session'] = params['token']
resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
ids = JSON.parse(resp.body)

ids.each do |id|
  flag = 0 # this changes to 1 when a change is made, so we don't post every resource

  obj = URI("#{params['url']}/subjects/#{id.to_s}")
  req = Net::HTTP::Get.new(obj)
  req['X-ArchivesSpace-Session'] = params['token']
  resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  record = JSON.parse(resp.body)

  if record['terms'][0]['term_type'] == "genre_form"
    if record['title'].end_with?('.')
      title = record['title'].chomp('.')
      record['title'] = title
    end
    flag = 1
  end

  if flag == 1
    # post the edited JSON back through the backend
    req = Net::HTTP::Post.new(obj)
    req['X-ArchivesSpace-Session'] = params['token']
    req['Content-Type'] = "application/json"
    req.body = record.to_json
    resp = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

    # puts whether the process succeeded or not
    if resp.code == "200"
      puts "Success: subjects/#{id.to_s}"
    else
      puts "Error: subjects/#{id.to_s}"
    end
  end
end
