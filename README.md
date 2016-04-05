# DU ArchivesSpace utilities

Reports for:

* batch exporting data serializations of various types (JSON, MARC, MODS, etc.)
* exporting ArchivesSpace user production reports over a given time period

These reports require a config.yml file which is not provided here. It contains the following fields:

**url:** the URL to your ArchivesSpace backend
**repo:** the URI for your ArchivesSpace repository (usually this is '/repositories/2'
**file_path:** the root file path where your exports will be stored; to this you should add subfolders for each serialization type ('marc,' 'json,' etc.)

Questions? E-mail kevin.clair [at] du [dot] edu.
