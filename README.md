# as_utils

Utilities we use in Special Collections and Archives at the University of Denver to work with our ArchivesSpace content. These are written in Perl and run from command line.

What's here:

* as_utils.pl: Sub-routines used by the other scripts.
* config.yml: Variables called upon by the other scripts.
* edit.pl: scaffolding for batch find/replace of records, into which we enter whatever change to a JSON object we want to make. For use until a more general find/replace utility exists.
* reports.pl: Batch reports for each data model in ArchivesSpace. Mostly JSON; some serializations (MODS for digital objects, MARC and EAD for resources, etc.)

These are subject to change and improvement as and when I have time.

Questions? E-mail kevin.clair [at] du [dot] edu.
