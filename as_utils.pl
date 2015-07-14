#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use JSON::Parse ':all';
use Term::ReadKey;
use LWP::UserAgent;
use Switch;
use Data::Dumper;

# initialize the user agent
# (set the timeout super-high so I can download EACs with lots of linked objects)
my $ua = LWP::UserAgent->new;
$ua->timeout(10000);

# get_file()
# Gets a file from user input.

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

# new_session(url)
# Gets a new session, if a user has not previously logged in.
# Runs when the script starts.
#
# Params:
# * url -- the URL to the ArchivesSpace backend.
# * count -- a variable that checks how many login attempts have been made. Stops trying after five attempts.

sub new_session {
  my($url, $i, $s, $l, $p);

  if($_[0]) { $url = $_[0]; } else {
    print "URL: ";
    chomp($url = <STDIN>);
  }
  if($_[1]) { $i = $_[1]; } else { $i = 0; }
  print "Logging into $url... \n";
  print "login: ";
  chomp($l = <STDIN>);
  print "password: ";
  ReadMode 2;
  chomp($p = <STDIN>);
  ReadMode 0;
  print "\n";

  my $resp = $ua->post("$url/users/$l/login?password=$p");
  if($resp->is_success) {
    my $response = decode_json($resp->decoded_content);
    $s = $response->{session};
  } else {
    $i++;
    if($i == 5) { 
      die "Login aborted after five attempts\n";
    } else {
      print "Login failed.\n";
      $s = &new_session($url, $i);
    }
  }

  return($s, $l, $p);
}

# refresh_session
# Gets a new session, using previously provided login credentials.
#
# Parameters:
# * url - the URL to the ArchivesSpace backend
# * login - username
# * password - password

sub refresh_session {
  my $s;
  my $resp = $ua->post("$_[0]/users/$_[1]/login?password=$_[2]");
  if($resp->is_success) {
    my $response = decode_json($resp->decoded_content);
    $s = $response->{session};
  } else {
    die "An error occurred.\n";
  }

  $s;
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
# * url = the URL to the backend server
# * session = the ArchivesSpace session ID, if needed

sub get_request {
  my($url, $session) = ($_[0], $_[1]);
  my $return;
  my $resp = $ua->get($url, 'X-ArchivesSpace-Session' => $session);
  my $sl = $resp->status_line();
  if($resp->is_success) {
    # Set this aside for refreshing sessions
    my $ct = $resp->header('Content-Type');
    $return = $resp->decoded_content;
  } else { 
    print "Error: $sl: $url\n";
    $return = '';
  }
  
  $return;
}
