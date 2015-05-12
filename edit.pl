#!/usr/bin/perl

# batch editing

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use YAML::XS 'LoadFile';
use POSIX qw(strftime);
use Data::Dumper;
use open ':std', ':encoding(UTF-8)';
binmode(STDOUT, ":utf8");

require 'as_utils.pl';
my $config = LoadFile('config.yml');

# initialize the user agent and config variables
my $ua = LWP::UserAgent->new;
my $url = $config->{url};
my $repo = $config->{repo};
my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
my $error_file = "/home/kevin/work/errors_$timestamp.txt";
if(-e $error_file) { unlink $error_file; }

my $session = &login($url);
$ua->default_header('X-ArchivesSpace-Session' => $session);

my $input = "../notes_pers_ids.txt";
open my $fh, "<", $input or die "Can't open $input: $!\n";
open my $fout, ">>", $error_file or die "Can't open $error_file: $!\n";
while(my $row = <$fh>) {
	chomp($row);
	my $req = HTTP::Request->new(GET => "$url/agents/people/$row");
	my $resp = $ua->request($req);
	my $record;
	if($resp->is_success) {
		$record = decode_json($resp->decoded_content);
		my $notes = $record->{notes};
		my $record_uri = $record->{uri};
		for my $note (@$notes) {
			my $subnotes = $note->{subnotes};
			for my $subnote (@$subnotes) {
				if($subnote->{jsonmodel_type} eq "note_text") {
					$subnote->{jsonmodel_type} = "note_abstract";
					my $content;
					push @$content, $subnote->{content};
					$subnote->{content} = $content;
				}
			}
			$note->{subnotes} = $subnotes;
		}
		$record->{notes} = $notes;
		my $record = encode_json($record);
		my $post_req = HTTP::Request->new(POST => "$url/agents/people/$row");
		$post_req->header("Content-Type" => "application/json");
		$post_req->content($record);
		$resp = $ua->request($post_req);
		my $response = decode_json($resp->decoded_content);
		if($resp->is_success) {
			my $status = $response->{status};
			my $uri = $response->{uri};
			print "$status: $uri\n";
			print $fout "$status: $uri\n";
		} else { 
			my $error = $response->{error};
			while ( my ($key, $values) = each %$error ) {
				for my $value (@$values) {
					print "Error: $record_uri: $key: $value\n";
					print $fout "Error: $record_uri: $key: $value\n";
				}
			}
		}
	} else { 
		my $status_line = $resp->status_line;
		print "Error: $record_uri: $status_line\n";
		print $fout "Error: $record_uri: $status_line\n";
	}
}
close $fout or die "Can't close $error_file: $!\n";
close $fh or die "Can't close $input: $!\n";
