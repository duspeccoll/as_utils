# as_utils

Utilities we use at DU to work with ArchivesSpace content. Mostly these are written in Perl and should be run from command line.

What's here:

* as_utils.pl: These are sub-routines that get used in other Perl scripts
* config.yml: Variables, mostly paths to which I write a file, to be called upon by the Perl scripts
* edit.pl: scaffolding for batch find/replace of records, into which we enter whatever change to a JSON object we want to make. For use until a more general find/replace utility exists.
* marc.pl: Script to batch export collection-level MARC records and modify them according to our local cataloging guidelines. Partially subsumed by reports.pl below.
* reports.pl: Reports, mostly JSON, for each of the data models in ArchivesSpace

These are subject to change and (hopefully) improvement as I have time to look at them.
