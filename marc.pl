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
my $config = LoadFile('config.yml');

# constants; change these for your local environment
my $backend = $config->{url};
my $repo = $config->{repo};
my $marc_path = $config->{marc_path};

my $session = &login($backend);
my $colls = &get_request("json", "$backend/$repo/resources?all_ids=true", $session);

for my $coll (@$colls) {
	my $json = &get_request("json", "$backend/$repo/resources/$coll", $session);
	my $file = &get_request("xml", "$backend/$repo/resources/marc21/$coll.xml", $session);
	my $id = lc($json->{id_0});
	my $filename = "$marc_path/$id"."_marc.xml";
	# ArchivesSpace sometimes outputs fields even if no value is present, which causes errors.
	# This next line deletes those fields to get around that.
	$file =~ s/\s+?<.+?\/>//g;
	my $record = MARC::Record->new_from_xml($file);

	# We had to hack Sierra to supply ind2=0 for genre headings with a subfield 2 so they'd index properly. This accounts for that.
	# Others would want to comment out or delete this next bit of code.
	my $genre;
	foreach $genre ($record->field('655')) {
		my $new_genre = $genre->clone();
		$new_genre->update( 'ind2' => "0" );
		$genre->replace_with($new_genre);
	}

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
	if(-e $filename) { unlink $filename; }
	my $file_out = MARC::File::XML->out($filename);
	$file_out->write($record);
}
print "\n";
