#!/usr/bin/perl

# reports.pl -- ArchivesSpace batch exports

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Switch;
use YAML::XS 'LoadFile';
use open ':std', ':encoding(UTF-8)';
binmode(STDOUT, ":utf8");

require 'as_utils.pl';

# Initialize the user agent
my $ua = LWP::UserAgent->new;

# Load config file
my $config = LoadFile('config.yml');
my $url = $config->{url};
my $repo = $config->{repo};

my $json_path = $config->{json_path};
my $eac_path = $config->{eac_path};
my $ead_path = $config->{ead_path};
my $marc_path = $config->{marc_path};

# Initialize ArchivesSpace session (may make more sense to do this in a subroutine)
#my $session = &new_session($url);
#$ua->default_header('X-ArchivesSpace-Session' => $session);

# Choose the data model to work with
my $model = &select_data_model();

# Select the report to run based on the data model
my $report = &select_report($model);

my $ids;

# Choose the type of report to run, based on the data model
if($model eq "agents") {
  &execute_report($report, "$model/people");
  &execute_report($report, "$model/corporate_entities");
  &execute_report($report, "$model/families");
  &execute_report($report, "$model/software");
} else {
  &execute_report($report, $model);
}

sub select_report {
  my $report_type;
  switch($_[0]) {
    case /agents/ {
      print "Select report type:\n* (1) Generic JSON\n* (2) EAC-CPF\n> ";
      chomp($report_type = <STDIN>);
      switch($report_type) {
        case 1 { $report_type = "json"; }
        case 2 { $report_type = "eac"; }
        else {
          print "Invalid entry, try again.\n";
          $report_type = &select_report($_[0]);
        }
      }
    }
    case /resources/ {
      print "Select report type:\n* (1) Generic JSON\n* (2) EAD\n* (3) MARC\n> ";
      chomp($report_type = <STDIN>);
      switch($report_type) {
        case 1 { $report_type = "json"; }
        case 2 { $report_type = "ead"; }
        case 3 { $report_type = "marc"; }
        else {
          print "Invalid entry, try again.\n";
          $report_type = &select_report($_[0]);
        }
      }
    }
    # The other reports will go here, but I haven't written them yet 
    else {
      print "Select report type:\n* (1) Generic JSON\n> ";
      chomp($report_type = <STDIN>);
      switch($report_type) {
        case 1 { $report_type = "json"; }
        else {
          print "Invalid entry, try again.\n";
          $report_type = &select_report($_[0]);
        }
      }
    }
  }

  return $report_type;
}

sub execute_report {
  my $report = $_[0];
  my $model = $_[1];
  my($s, $l, $p);
  #my $session = "da40aefff8554d12a18ac3174e8d4cdb398b7688da2111d0d3ed20211b376e6c";

  if($_[2]) { $s = $_[2]; } else {
    ($s, $l, $p) = &new_session($url);
  }

  $ua->default_header('X-ArchivesSpace-Session' => $s);

  my $ids;
  switch($model) {
    case /subjects/ { 
      print "Grab $url/$model IDs... \n";
      $ids = $ua->get("$url/$model?all_ids=true");
    }
    case /^agents/ { 
      print "Grab $url/$model IDs... \n";
      $ids = $ua->get("$url/$model?all_ids=true"); 
    }
    else { 
      print "Grab $url/$repo/$model IDs... \n";
      $ids = $ua->get("$url/$repo/$model?all_ids=true");
    }
  }

  if($ids->code() eq 404) { die "Error: ".$ids->status_line().": $model\n"; } else {
    $ids = decode_json($ids->decoded_content);
    my $size = @$ids;
    my $i = 0;
    switch($report) {
      case /json/ {
        my $model_url;
        switch($model) {
          case /subjects/ { $model_url = "$url/$model"; }
          case /^agents/ { $model_url = "$url/$model"; }
          else { $model_url = "$url/$repo/$model"; }
        }
        $model =~ s/agents\///g;
        my $file_output = "$json_path/$model"."_report.json";
        if(-e $file_output) { unlink $file_output; }
        print "Writing report to $file_output... \n";
        open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
        print $fh "{\"model\":\[";
        for my $id (@$ids) {
          $i++;
          my $record = &get_request("$model_url/$id", $s);
          print $fh $record;
          if($i < $size) { print $fh ","; }
        }
        print $fh "\]}";
        close $fh or die "Error closing $file_output: $!\n";
      }
      case /eac/ {
        $model =~ s/agents\///g;
        $model =~ s/software/softwares/;
        for my $id (@$ids) {
          my $model_url = "$url/$repo/archival_contexts/$model/$id.xml";
          my $file_output = "$eac_path/$model"."_"."$id"."_eac.xml";
          # this is because the DU EAC record takes too long to export
          if($model_url !~ m/corporate_entities\/1506/) {
            print "$model_url\n";
            my $record = &get_request($model_url, $s);
            if(-e $file_output) { unlink $file_output; }
            open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
            print $fh $record;
            close $fh or die "Error closing $file_output: $!\n";
          }
        }
      }
      case /marc/ {
        for my $id (@$ids) {
          my $model_url = "$url/$repo/$model/marc21/$id.xml";
          #my $resource = &get_request("$url/$repo/$model/$id", $s);
          my $resource = decode_json(&get_request("$url/$repo/$model/$id", $s));
          my $num = lc($resource->{id_0});
          my $title = $resource->{title};
          print "Downloading MARC record for $num $title... \n";
          my $record = &get_request($model_url, $s);
          if($record) {
            my $file_output = "$marc_path/$num"."_marc.xml";
            print "Writing $file_output... \n";
            if(-e $file_output) { unlink $file_output; }
            open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
            print $fh $record;
            close $fh or die "Error closing $file_output: $!\n";
          }
        }
      }
      case /ead/ {
        for my $id (@$ids) {
          my $model_url = "$url/$repo/resource_descriptions/$id.xml";
          my $resource = &get_request("$url/$repo/$model/$id", $s);
          $resource = decode_json($resource);
          my $num = lc($resource->{id_0});
          my $title = $resource->{title};
          print "Downloading EAD for $num $title... \n";
          my $ead = &get_request($model_url, $s);
          if($ead) {
            my $file_output = "$ead_path/$num"."_ead.xml";
            print "Writing $file_output... \n";
            if(-e $file_output) { unlink $file_output; }
            open my $fh, '>>', $file_output or die "Error opening $file_output: $!\n";
            print $fh $ead;
            close $fh or die "Error closing $file_output: $!\n";
          }
        }
      }
    }
  }
}
