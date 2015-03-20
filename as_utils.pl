#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use Term::ReadKey;
use LWP::UserAgent;
use Switch;

# initialize the user agent

my $ua = LWP::UserAgent->new;

# login(url)
# Handles logging into the ArchivesSpace backend.
#
# Params:
# * url -- the URL to the ArchivesSpace backend.

sub login {
	my $s;
	my $n;
	print "Logging into $_[0]... \n";
	if($_[1]) { $n = $_[1]; } else { $n = 0; }
	print "login: ";
	my $login = <STDIN>;
	chomp($login);
	print "password: ";
	ReadMode 2;
	my $pwd = <STDIN>;
	chomp($pwd);
	ReadMode 0;
	print "\n";

	my $server_endpoint = "$_[0]/users/$login/login?password=$pwd";
	my $req = HTTP::Request->new(POST => $server_endpoint);
	my $resp = $ua->request($req);
	if($resp->is_success) {
		my $response = decode_json($resp->decoded_content);
		$s = $response->{session};
	} else {
		$n++;
		if($n == 5) { 
			die "Login aborted after five attempts\n";
		} else {
			print "Login failed.\n";
			$s = &login($_[0], $n);
		}
	}

	$s;
}

# get_file()
# Get the filename. Expects JSON.
#
# TODO: Validate upon receipt

sub get_file {
	print "Enter a valid JSON file: ";
	my $f = <STDIN>;
	chomp($f);
	if(! -e $f) {
		print "$f does not exist.\n";
		$f = &get_file();
	}

	$f;
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
	my $return;
	if($resp->is_success) {
		$return = decode_json($resp->decoded_content);
	} else { die "An error occurred.\n"; }

	$return;
}

sub get_xml_request {
	my $req = HTTP::Request->new(GET => $_[0]);
	$req->header('X-ArchivesSpace-Session' => $_[1]);
	my $resp = $ua->request($req);
	my $return;
	if($resp->is_success) {
		$return = $resp->decoded_content;
	} else { die "An error occurred.\n"; }

	$return;
}
