require 'mysql2'
require 'io/console'

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
	file_output = "~/reports/#{row['username'].gsub(/\./,'_')}_#{from.gsub(/-/,'')}-#{to.gsub(/-/,'')}.txt"
	File.delete(file_output) if File.exist?(file_output)
  records = client.query("SELECT x.title, x.id, x.uri FROM(
    SELECT title, identifier id, CONCAT('/repositories/', repo_id, '/resource/', id) uri, created_by, create_time FROM resource
    UNION
    SELECT title, component_id id, CONCAT('/repositories/', repo_id, '/archival_objects/', id) uri, created_by, create_time FROM archival_object
    UNION
    SELECT title, digital_object_id id, CONCAT('/repositories/', repo_id, '/digital_objects/', id) uri, created_by, create_time FROM digital_object
    UNION
    SELECT title, identifier id, CONCAT('/repositories/', repo_id, '/accessions/', id) uri, created_by, create_time FROM accession
    UNION
    SELECT title, authority_id id, CONCAT('/subjects/', id) uri, created_by, create_time FROM subject
    UNION
    SELECT T1.sort_name title, T2.authority_id id, CONCAT('/agents/people/', T1.agent_person_id) uri, T1.created_by, T1.create_time FROM name_person T1 JOIN name_authority_id T2 ON T1.id=T2.name_person_id
    UNION
    SELECT T1.sort_name title, T2.authority_id id, CONCAT('/agents/corporate_entities/', T1.agent_corporate_entity_id) uri, T1.created_by, T1.create_time FROM name_corporate_entity T1 JOIN name_authority_id T2 ON T1.id=T2.name_corporate_entity_id
    UNION
    SELECT T1.sort_name title, T2.authority_id id, CONCAT('/agents/families/', T1.agent_family_id) uri, T1.created_by, T1.create_time FROM name_family T1 JOIN name_authority_id T2 ON T1.id=T2.name_family_id
  ) x WHERE x.created_by='#{row['username']}' AND x.create_time BETWEEN '#{from}' AND '#{to}'")

	if records.count > 0
		puts "Writing #{file_output}"
		header = records.fields.join("\t")
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
