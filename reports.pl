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
use Switch;
use YAML::XS 'LoadFile';
use open ':std', ':encoding(UTF-8)';
binmode(STDOUT, ":utf8");

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
my $ids;
if($model eq "agents") {
	my $report_type = &get_report_type($model);
	# we need to do all four types of agents separately
	$ids = $ua->get("$model_url/people?all_ids=true");
	&report_urls($ids, $report_type, "people", "$model_url/people", $session);
	$ids = $ua->get("$model_url/corporate_entities?all_ids=true");
	&report_urls($ids, $report_type, "corporate_entities", "$model_url/corporate_entities", $session);
	$ids = $ua->get("$model_url/families?all_ids=true");
	&report_urls($ids, $report_type, "families", "$model_url/families", $session);
	$ids = $ua->get("$model_url/software?all_ids=true");
	&report_urls($ids, $report_type, "software", "$model_url/software", $session);
} elsif($model eq "resources") {
	my $report_type = &get_report_type($model);
	$ids = $ua->get("$model_url?all_ids=true");
	&report_urls($ids, $report_type, $model, $model_url);
} else {
	$resp = $ua->get("$model_url?all_ids=true");
	&report_urls($resp, "json", $model, $model_url);
}

sub get_report_type {
	my $report_type;
	my $model = $_[0];
	switch($model) {
		case /resources/ {
			print "Select report type:\n* (1) Generic JSON\n* (2) EAD\n* (3) MARC\n> ";
			$report_type = <STDIN>;
			chomp($report_type);
			switch($report_type) {
				case 1 { $report_type = "json"; }
				case 2 { $report_type = "ead"; }
				case 3 { $report_type = "marc"; }
				else {
					print "Invalid entry, try again.\n";
					$report_type = &get_report_type($_[0]);
				}
			}
		}
		case /agents/ {
			print "Select report type:\n* (1) Generic JSON\n* (2) EAC-CPF\n> ";
			$report_type = <STDIN>;
			chomp($report_type);
			switch($report_type) {
				case 1 { $report_type = "json"; }
				case 2 { $report_type = "eac"; }
				else {
					print "Invalid entry, try again.\n";
					$report_type = &get_report_type($_[0]);
				}
			}
		}
		else { print "Other types not yet supported.\n"; }
	}

	$report_type;
}

sub report_urls {
	my $response = $_[0];
	my $report_type = $_[1];
	my $model = $_[2];
	my $model_url = $_[3];
	my $session = $_[4];
	my $json_path = $config->{json_path};
	my $eac_path = $config->{eac_path};
	if($response->code() eq 404) { die "Error: ".$response->status_line().": $model\n"; } else {
		my $ids = decode_json($response->decoded_content);
		my $size = @$ids;
		my $i = 0;
		switch($report_type) {
			case /json/ {
				my $file_output = "$json_path/$model"."_report.json";
				if(-e $file_output) { unlink $file_output; }
				print "Writing report to $file_output... \n";
				open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
				print $fh "{\"$model\":\[";
				for my $id (@$ids) { 
					$i++;
					my $record = &get_request("$model_url/$model_id", $session);
					$record = decode_json($record);
					print $fh $record;
					if($i < $size) { print $fh ","; }
				}
				print $fh "\]}";
				close $fh or die "Error closing $file_output: $!\n";
			}
			case /eac/ {
				if($model eq "software") { $model = "softwares"; }
				for my $id (@$ids) {
					$i++;
					print "$url/$repo/archival_contexts/$model/$model_id.xml\n";
					my $record = &get_request("$url/$repo/archival_contexts/$model/$model_id.xml", $session);
					my $file_output = "$eac_path/$model"."_"."$model_id"."_eac.xml";
					if(-e $file_output) { unlink $file_output; }
					open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
					print $fh $record;
					close $fh or die "Error closing $file_output: $!\n";
				}
			}
		}
	}
}
