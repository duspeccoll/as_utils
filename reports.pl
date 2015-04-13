#!/usr/bin/perl

# reports.pl -- getting a bunch of ASpace data at once
#
# This is extremely bare-bones: just a bunch of URLs, none of which are pulled from the JSON.
# Still working on extending it for various use cases.
#
# Once reports are functional I won't need these anymore but I don't want to wait that long to do reporting.

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use YAML::XS 'LoadFile';

require 'as_utils.pl';
my $config = LoadFile('config.yml');

# Initialize the user agent
my $ua = LWP::UserAgent->new;
my $url = $config->{url};
my $repo = $config->{repo};

my $session = &login($url);
$ua->default_header('X-ArchivesSpace-Session' => $session);
my $model = &select_data_model();
my $model_url;
if($model eq "agents" or $model eq "subjects") {
	$model_url = "$url/$model";
} else { $model_url = "$url/$repo/$model"; }
print "Fetching array of $model...\n";
my $resp;
if($model eq "agents") {
	# we need to do all four types of agents separately
	$resp = $ua->get("$model_url/people?all_ids=true");
	&report_urls($resp, "$model_url/people");
	$resp = $ua->get("$model_url/corporate_entities?all_ids=true");
	&report_urls($resp, "$model_url/corporate_entities");
	$resp = $ua->get("$model_url/families?all_ids=true");
	&report_urls($resp, "$model_url/families");
	$resp = $ua->get("$model_url/software?all_ids=true");
	&report_urls($resp, "$model_url/software");
} else {
	$resp = $ua->get("$model_url?all_ids=true");
	&report_urls($resp, $model_url);
}

sub report_urls {
	my $response = $_[0];
	my $url = $_[1];
	if($response->code() eq 404) { die "Error: ".$response->status_line().": $_[1]\n"; } else {
		my $model_ids = decode_json($resp->decoded_content);
		for my $model_id (@$model_ids) {
			my $record_url = "$url/$model_id";
			print "$record_url\n";
		}
	}
}
