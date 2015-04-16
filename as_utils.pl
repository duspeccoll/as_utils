#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use JSON::Parse ':all';
use Term::ReadKey;
use LWP::UserAgent;
use Switch;

# initialize the user agent
my $ua = LWP::UserAgent->new;

# Utilities contained in this file, in order:
#
# 1. get_file
# 2. login
# 3. select_data_model
# 4. get_agent_class
# 5. get_request (contains json and xml as separate requests)


# get_file()
# Gets a file from user input.
#
# TODO: Test if the JSON is valid

sub get_file {
	print "Enter a valid JSON file: ";
	my $f = <STDIN>;
	chomp($f);
	if(! -e $f) {
		print "$f does not exist.\n";
		$f = &get_file();
	}
	
	my $json;
	{
		local $/;
		open my $fh, '<', $f or die "Can't open $f: $!\n";
		$json = <$fh>;
		close $fh;
	}

	if(valid_json($json)) {
		$json;
	} else {
		print "$f failed to validate, try again.\n";
		$f = &get_file();
	}
}

# login(url)
# Handles logging into the ArchivesSpace backend.
#
# Params:
# * url -- the URL to the ArchivesSpace backend.
# * count -- a variable that checks how many login attempts have been made.
#     (login() stops trying after five attempts)

sub login {
	my $url;
	my $count;
	my $login;
	my $password;
	my $session;

	if($_[0]) { $url = $_[0]; } else {
		print "URL: ";
		$url = <STDIN>;
		chomp($url);
	}
	print "Logging into $url... \n";
	if($_[1]) { $count = $_[1]; } else { $count = 0; }
	if($_[2]) { $login = $_[2]; } else {
		print "login: ";
		$login = <STDIN>;
		chomp($login);
	}
	if($_[3]) { $password = $_[3]; } else {
		print "password: ";
		ReadMode 2;
		$password = <STDIN>;
		chomp($password);
		ReadMode 0;
	}
	print "\n";

	my $resp = $ua->post("$url/users/$login/login?password=$password");
	if($resp->is_success) {
		my $response = decode_json($resp->decoded_content);
		$session = $response->{session};
	} else {
		$count++;
		if($count == 5) { 
			die "Login aborted after five attempts\n";
		} else {
			print "Login failed.\n";
			$session = &login($url, $count);
		}
	}

	$session;
}

# select_data_model
# Selects a data model from user input.

sub select_data_model { 
	my $model;
	print "Select a data model:\n";
	print "* (1) Resources\n";
	print "* (2) Archival Objects\n";
	print "* (3) Agents\n";
	print "* (4) Subjects\n";
	print "* (5) Digital Objects\n";
	print "> ";
	$model = <STDIN>;
	chomp($model);
	switch($model) {
		case 1 { $model = "resources"; }
		case 2 { $model = "archival_objects"; }
		case 3 { $model = "agents"; }
		case 4 { $model = "subjects"; }
		case 5 { $model = "digital_objects"; }
		else {
			print "Invalid entry, try again.\n";
			$model = &select_data_model();
		}
	}

	$model;
}

# get_agent_class(path)
# Assigns a class to agents based on user input.
#
# Params:
# * path = the path to the API entered by the user

sub get_agent_class {
	my $class;
	switch($_[0]) {
		case /^agents\/people\/\d+?$/ { $class = "people"; }
		case /^agents\/corporate_entities\/\d+?$/ { $class = "corporate_entities"; }
		case /^agents\/families\/\d+?$/ { $class = "families"; }
		case /^agents\/software\/\d+?$/ { $class = "software"; }
		else { die "Invalid entry: $_[0]\n"; }
	}

	$class;
}

# get_request(type, url, session)
# Places an HTTP GET request with the ArchivesSpace backend.
#
# Params:
# * type = the response type we expect to get back (JSON, XML, etc.)
# * url = the URL to the backend server
# * session = the ArchivesSpace session ID, if needed

sub get_request {
	my $return;
	my $resp = $ua->get($_[1], 'X-ArchivesSpace-Session' => $_[2]);
	if($_[0] eq "json") {
		$return = decode_json($resp->decoded_content);
	} else {
		$return = $resp->decoded_content; 
	}
	if($resp->is_error) { die "An error occurred: $resp->status_line\n"; }

	$return;
}
