#!/usr/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Switch;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );
use YAML::XS 'LoadFile';

require 'as_utils.pl';

my $ua = LWP::UserAgent->new;

# constants; change these for your local environment
my $backend = $config->{url};
my $repo = $config->{repo};

my $session = &login($backend);
my $colls = &get_request("json", "$backend/$repo/resources?all_ids=true", $session);

for my $coll (@$colls) {
	my $json = &get_request("json", "$backend/$repo/resources/$coll", $session);
	my $file = &get_request("xml", "$backend/$repo/resources/marc21/$coll.xml", $session);
	my $id = lc($json->{id_0});
	my $filename = "marc/$id"."_marc.xml";
	# ArchivesSpace sometimes outputs fields even if no value is present, which causes errors.
	# This next line deletes those fields to get around that.
	$file =~ s/\s+?<.+?\/>//g;
	my $record = MARC::Record->new_from_xml($file);
	my $extdocs = $json->{external_documents};
	for my $extdoc (@$extdocs) {
		switch($extdoc->{title}) {
			case /Encore record/ { 
				my $sierra = $extdoc->{location};
				if($sierra) {
					if($sierra =~ m/^\./) {
						$sierra = "*recs=b,b3=z,ov=$sierra";
					} else { $sierra = "*recs=b,b3=z,ov=.$sierra"; }
					my $marc_949 = MARC::Field->new('949',' ',' ','a' => $sierra);
					$record->append_fields($marc_949);
				}
			}
			case /OCLC record/ { 
				my $oclc = $extdoc->{location};
				if($oclc) {
					$oclc =~ s/http:\/\/worldcat.org\/oclc\///;
					my $marc_035 = MARC::Field->new('035',' ',' ','a' => "\(OCoLC\)$oclc");
					$record->append_fields($marc_035);
				}
			}
			case /Digital DU collection/ { 
				my $adr = $extdoc->{location};
				if($adr) {
					my $marc_856 = MARC::Field->new('856','4','1',
						'z' => "Access collection materials in Digital DU",
						'u' => $adr);
					$record->append_fields($marc_856);
				}
			}
		}
	}
	my $file_out = MARC::File::XML->out($filename);
	print "Writing $filename\n";
	$file_out->write($record);
}
