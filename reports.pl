#!/usr/bin/perl

# reports.pl -- getting a bunch of ASpace data at once
#
# Basically this just gets a list of IDs for each data model and then downloads the JSON for all of them.
# From there I'd just run it through Open Refine or something, until I have time to do more interesting things with it.
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
my $resp;
if($model eq "agents") {
	# we need to do all four types of agents separately
	$resp = $ua->get("$model_url/people?all_ids=true");
	&report_urls($resp, $model, "$model_url/people");
	$resp = $ua->get("$model_url/corporate_entities?all_ids=true");
	&report_urls($resp, $model, "$model_url/corporate_entities");
	$resp = $ua->get("$model_url/families?all_ids=true");
	&report_urls($resp, $model, "$model_url/families");
	$resp = $ua->get("$model_url/software?all_ids=true");
	&report_urls($resp, $model, "$model_url/software");
} else {
	$resp = $ua->get("$model_url?all_ids=true");
	&report_urls($resp, $model, $model_url);
}

sub report_urls {
	my $response = $_[0];
	my $model = $_[1];
	my $url = $_[2];
	if($response->code() eq 404) { die "Error: ".$response->status_line().": $_[1]\n"; } else {
		my $file_output = $model."_report.json";
		if(-e $file_output) { unlink $file_output; }
		print "Writing report to $file_output... \n";
		open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
		print $fh "{\"$model\":\[";
		my $model_ids = decode_json($response->decoded_content);
		my $size = @$model_ids;
		my $i = 0;
		for my $model_id (@$model_ids) {
			$i++;
			print "Writing $url record $i of $size...\r";
			my $record_url = "$url/$model_id";
			my $json_response = $ua->get($record_url);
			my $record = $json_response->decoded_content;
			print $fh $record;
			if($i != $size) { print $fh ","; }
		}
		print $fh "\]}";
		close $fh or die "Error closing $file_output: $!\n";
	}
	print "\n";
}
