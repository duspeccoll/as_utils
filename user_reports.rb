#!/usr/bin/env ruby

require 'mysql2'
require 'io/console'

frontend = "http://duarchstaff.coalliance.org"
print "Enter mysql password for the 'as' user: "
password = STDIN.noecho(&:gets).chomp

client = Mysql2::Client.new( :host => "localhost",
                             :username => "as",
                             :password => password,
                             :database => "archivesspace" )
print "\nEnter begin date: "
from = gets.chomp
print "Enter end date: "
to = gets.chomp
users = client.query("SELECT username FROM user").each do |row|
  # this is hard-coded to write to the 'reports' subfolder in my home directory
  file_output = "/Users/jackflaps/reports/#{row['username'].gsub(/\./,'_')}_#{from.gsub(/-/,'')}-#{to.gsub(/-/,'')}.txt"
  records = client.query("SELECT x.title, x.id, x.uri FROM(
    SELECT title, identifier id, CONCAT('#{frontend}/resources/', id) uri, created_by, create_time, last_modified_by, user_mtime FROM resource WHERE repo_id=2
    UNION
    SELECT title, component_id id, CONCAT('#{frontend}/resources/', root_record_id, '\#tree::archival_object_', id) uri, created_by, create_time, last_modified_by, user_mtime FROM archival_object WHERE repo_id=2
    UNION
    SELECT title, digital_object_id id, CONCAT('#{frontend}/digital_objects/', id) uri, created_by, create_time, last_modified_by, user_mtime FROM digital_object WHERE repo_id=2
    UNION
    SELECT title, identifier id, CONCAT('#{frontend}/accessions/', id) uri, created_by, create_time, last_modified_by, user_mtime FROM accession WHERE repo_id=2
    UNION
    SELECT title, authority_id id, CONCAT('#{frontend}/subjects/', id) uri, created_by, create_time, last_modified_by, user_mtime FROM subject
    UNION
    SELECT T1.sort_name title, T2.authority_id id, CONCAT('#{frontend}/agents/agent_person/', T1.agent_person_id) uri, T1.created_by, T1.create_time, T1.last_modified_by, T1.user_mtime FROM name_person T1 JOIN name_authority_id T2 ON T1.id=T2.name_person_id
    UNION
    SELECT T1.sort_name title, T2.authority_id id, CONCAT('#{frontend}/agents/agent_corporate_entity/', T1.agent_corporate_entity_id) uri, T1.created_by, T1.create_time, T1.last_modified_by, T1.user_mtime FROM name_corporate_entity T1 JOIN name_authority_id T2 ON T1.id=T2.name_corporate_entity_id
    UNION
    SELECT T1.sort_name title, T2.authority_id id, CONCAT('#{frontend}/agents/agent_family/', T1.agent_family_id) uri, T1.created_by, T1.create_time, T1.last_modified_by, T1.user_mtime FROM name_family T1 JOIN name_authority_id T2 ON T1.id=T2.name_family_id
  ) x WHERE
    x.created_by='#{row['username']}' AND x.create_time BETWEEN '#{from}' AND '#{to}'
    OR x.last_modified_by='#{row['username']}' AND x.user_mtime BETWEEN '#{from}' AND '#{to}'")

  if records.count > 0
    puts "Writing #{file_output}"
    header = records.fields.join("\t")
    File.delete(file_output) if File.exist?(file_output)
    File.open(file_output, 'w') { |f| f.write "#{header}\n" }
    records.each do |record|
      File.open(file_output, 'a') { |f|
        f.write "#{record['title']}\t"
        if record['id']
          f.write "#{record['id'].gsub(",null","").gsub("[\"","").gsub("\"]","")}\t"
        else
          f.write "\t"
        end
        f.write "#{record['uri']}\n"
      }
    end
  end
end
