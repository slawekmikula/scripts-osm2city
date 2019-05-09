# scripts-osm2city
Scripts for osm2city parsing and generation

directory structure
-------------------

* read the documentation for osm2city on: http://osm2city.readthedocs.io
* directory structure should be the same as in this documentation in: http://osm2city.readthedocs.io/en/latest/preparation.html#creating-a-directory-structure
* additionaly in development directory you should download and extract osmosis (lastest stable)
* remeber to have terragear data on your disk for selected area ! Downloat it here: http://www.flightgear.org/download/scenery/
* I prefer to create python virtualenv specifically for this task and this should be in the same directory
* my directory structure looks like:

 osm2city
  - development
   - osm2city (repository https://gitlab.com/fg-radi/osm2city)
   - osm2city-data (repository https://gitlab.com/fg-radi/osm2city-data)
   - osmosis (http://wiki.openstreetmap.org/wiki/Osmosis#Downloading)
   - virtualenv (see below)
  - fg_customscenery
   - projects (this repository cloned)
  - flightgear
   - fgfs_terrasync

create virtualenv
-----------------
I prefer to create separate library location for python 3.5. To do this, perform these steps:

* virtualenv --python=python3.5 virtualenv
* cd virtualenv
* ./bin/pip install numpy
* ./bin/pip install matplotlib
* ./bin/pip install networkx
* ./bin/pip install pillow
* ./bin/pip install scipy
* ./bin/pip install lapack
* ./bin/pip install blas
* ./bin/pip install shapely
* ./bin/pip install psycopg2
* ./bin/pip install imaging

or with one liner

* ./bin/pip install numpy matplotlib networkx pillow scipy lapack blas shapely psycopg2 imaging

After this You have complete library strucuture in separate environment.


create databases
----------------
Look into db subdirectory. You have to install postgresql server with postgis extension.
Scripts should be run in numbered oder 01-05.
After this you should have DB prepared for script work.

run data
------------

Prepare and configure application scripts:

* Edit config.conf and provide paths to data/flightgear directories or binaries
* Edit sources.conf file. In origin it lists paths from geofabrik URL for Poland area. REMEBER last line must be empty !
* In order to find proper entry go to geofabrik data e.g. http://download.geofabrik.de/europe/poland/dolnoslaskie.html
* Search for OSM XML file to download e.g. http://download.geofabrik.de/europe/poland/dolnoslaskie-latest.osm.bz2
* Enter in sources.conf only europe/poland-dolnoslaskie in single line

Now you can run script. It will go through all items in sources.conf, download it,
extract, create ini files, upload data do DB and run osm2city in batch mode for the
whole area of the OSM data.

After that, you will have directories for inclusion in FlightGear scenery and
archive to redistribute.

Have fun !
