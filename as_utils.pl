#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use Term::ReadKey;
use LWP::UserAgent;
use Switch;

# initialize the user agent

my $ua = LWP::UserAgent->new;

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

	$json;
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

	my $server_endpoint = "$url/users/$login/login?password=$password";
	my $req = HTTP::Request->new(POST => $server_endpoint);
	my $resp = $ua->request($req);
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
		case /^agents\/software\/\d+?$/ { $class = "softwares"; }
		else { die "Invalid entry: $_[0]\n"; }
	}

	$class;
}

# get_request(url, session)
# Places an HTTP GET request with the ArchivesSpace backend.
#
# Params:
# * url = the URL to the backend server
# * session = the ArchivesSpace session ID, if needed

sub get_json_request {
	my $req = HTTP::Request->new(GET => $_[0]);
	$req->header('X-ArchivesSpace-Session' => $_[1]);
	my $resp = $ua->request($req);
	my $return = decode_json($resp->decoded_content);
	if($resp->is_error) { die "An error occurred: $resp->status_line\n"; }

	$return;
}

sub get_xml_request {
	my $req = HTTP::Request->new(GET => $_[0]);
	$req->header('X-ArchivesSpace-Session' => $_[1]);
	my $resp = $ua->request($req);
	my $return = $resp->decoded_content;
	if($resp->is_error) { die "An error occurred: $resp->status_line\n"; }

	$return;
}
