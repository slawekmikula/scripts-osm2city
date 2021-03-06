#!/bin/bash

# create destination directory
function create_dir() {
    echo "create_dir"
    source=$1
    mkdir -p $source
}

# get data from geofabrik host
function download_osmdata {
    echo "download_osmdata"
    source=$1
    file=`basename $source`
    wget $SOURCE_URL/$SOURCE_PREFIX$source$SOURCE_POSTFIX -O $source/$file$SOURCE_POSTFIX
}

# extract geofabrik data
function extract_osmdata {
    echo "extract_osmdata"
    source=$1
    file=`basename $source`
    bunzip2 $source/$file$SOURCE_POSTFIX
}

# find coordinates in OSM file
function find_coordinates {
    echo "find_coordinates"

    source=$1
    file=`basename $source`

    #<bounds minlat="50.17974" minlon="19.69901" maxlat="51.34824" maxlon="21.8758"/>
    SOUTH=`head -n 5 $source/$file$SOURCE_POSTFIX_RAW | grep bounds | gawk 'match($0, /.*<bounds minlat="(.*)" minlon="(.*)" maxlat="(.*)" maxlon="(.*)"\/>.*/, a) {print a[1]}'`
    WEST=`head -n 5 $source/$file$SOURCE_POSTFIX_RAW | grep bounds | gawk 'match($0, /.*<bounds minlat="(.*)" minlon="(.*)" maxlat="(.*)" maxlon="(.*)"\/>.*/, a) {print a[2]}'`
    NORTH=`head -n 5 $source/$file$SOURCE_POSTFIX_RAW | grep bounds | gawk 'match($0, /.*<bounds minlat="(.*)" minlon="(.*)" maxlat="(.*)" maxlon="(.*)"\/>.*/, a) {print a[3]}'`
    EAST=`head -n 5 $source/$file$SOURCE_POSTFIX_RAW | grep bounds | gawk 'match($0, /.*<bounds minlat="(.*)" minlon="(.*)" maxlat="(.*)" maxlon="(.*)"\/>.*/, a) {print a[4]}'`
}

# set coordinates from COORDINATES
function set_coordinates {
    echo "set_coordinates"

    # 20.0_50.0_20.25_50.125
    IFS='_' read -r -a coords <<< "$1"
    WEST=${coords[0]}
    SOUTH=${coords[1]}
    EAST=${coords[2]}
    NORTH=${coords[3]}
    
    echo "Set: NORTH: $NORTH EAST: $EAST SOUTH: $SOUTH WEST: $WEST"
}


# copy ini file from template
function copy_ini {
    echo "copy_ini"
    source=$1
    cp template.ini $source/`basename $source`.ini
}

# modify template ini file with correct variables
function modify_ini {
    echo "modify_ini"

    source=$1
    file=`basename $source`
    sed_source_underscore=${source//\//\\/}
    scenery_path_escape=${SCENERY_PATH//\//\\/}
    output_path_escape=${OUTPUTH_PATH//\//\\/}
    osmcity_datadir_escape=${OSMCITY_DATADIR//\//\\/}
    fgelev_path_escape=${FGELEV_PATH//\//\\/}
    path_to_scenery_opt_escape=${PATH_TO_SCENERY_OPT//\//\\/}

    sed -i "s/{scenery_optional}/${path_to_scenery_opt_escape}/g" $source/`basename $source`.ini
    sed -i "s/{prefix}/${sed_source_underscore}/g" $source/`basename $source`.ini
    sed -i "s/{scenery_path}/${scenery_path_escape}/g" $source/`basename $source`.ini
    sed -i "s/{output_path}/${output_path_escape}/g" $source/`basename $source`.ini
    sed -i "s/{destination_dir}/${sed_source_underscore}/g" $source/`basename $source`.ini
    sed -i "s/{osmcity_data}/${osmcity_datadir_escape}/g" $source/`basename $source`.ini
    sed -i "s/{source_data}/${sed_source_underscore}/g" $source/`basename $source`.ini

    sed -i "s/{boundary_east}/${EAST}/g" $source/`basename $source`.ini
    sed -i "s/{boundary_west}/${WEST}/g" $source/`basename $source`.ini
    sed -i "s/{boundary_north}/${NORTH}/g" $source/`basename $source`.ini
    sed -i "s/{boundary_south}/${SOUTH}/g" $source/`basename $source`.ini

    sed -i "s/{fgelev_path}/${fgelev_path_escape}/g" $source/`basename $source`.ini
    sed -i "s/{db_host}/${DB_HOST}/g" $source/`basename $source`.ini
    sed -i "s/{db_port}/${DB_PORT}/g" $source/`basename $source`.ini
    sed -i "s/{db_name}/${DB_NAME}/g" $source/`basename $source`.ini
    sed -i "s/{db_user}/${DB_USER}/g" $source/`basename $source`.ini
    sed -i "s/{db_password}/${DB_PASSWORD}/g" $source/`basename $source`.ini

}

# truncate OSM DB
function exe_truncate_db {
    echo "exe_truncate_db"
    $DEVPATH/osmosis/bin/osmosis --truncate-pgsql database=$DB_NAME user=$DB_USER password=$DB_PASSWORD
}

# load new data to OSM DB
function exe_read_db {
    echo "exe_read_db"
    source=$1
    file=`basename $source`
    $DEVPATH/osmosis/bin/osmosis --read-xml $source/$file$SOURCE_POSTFIX_RAW --log-progress --write-pgsql database=$DB_NAME user=$DB_USER password=$DB_PASSWORD
}

# run osm2city in batch mode
function exe_batch {
    echo "exe_batch"
    source=$1
    current_dir=`pwd`
    file=`basename $source`

    PYTHONPATH=$PYTHONPATH:$DEVPATH/osm2city
    FG_ROOT=$FG_ROOT
    export PYTHONPATH
    export FG_ROOT

    # add * before WEST when WEST is negative (by paju1986, vanosten)
    if (( $(echo "$WEST < 0" |bc -l) )); then
        WEST="*$WEST"
    fi

    cd $source
    echo "--------------------- EXE BATCH -----------------------------------" >> output.log
    $PYTHON_BIN $OSMCITY_DIR/build_tiles.py -f $file.ini -l DEBUG -p 3 -b ${WEST}_${SOUTH}_${EAST}_${NORTH} >> output.log
    cd $current_dir
}

# compress result data
function exe_zip_result {
    echo "exe_zip_result"
    source=$1
    current_dir=`pwd`
    sed_source_underscore=${source//\//_}
    cd ..
    echo "--------------------- ZIP RESULT -----------------------------------" >> $current_dir/$source/output.log
    zip -r $sed_source_underscore.zip $source >> $current_dir/$source/output.log
    cd $current_dir
}

. custom.conf
. config.conf

if [ $# -eq 1 ]; 
then
    if [[ "$1" = "reprocess" ]];
    then
        previous=""
        while read line; do
          if [[ $line != \#* ]]
          then
              echo "Reprocessing: $line"
              IFS=', ' read -r -a array <<< "$line"
              p="${array[0]}"
              COORDINATES="${array[1]}"
              echo "Directory: $p"
              echo "Coordinates: $COORDINATES"
              
              echo "--------------------- START PROCESSING -----------------------------------" > $p/output.log

              create_dir $p
              file=`basename $source`
              if [ ! -e "$p/$file$SOURCE_POSTFIX_RAW" ] && [[ $previous != $p ]];
              then                      
                  download_osmdata $p
                  extract_osmdata $p
                  exe_truncate_db $p
                  exe_read_db $p
                  previous=$p;
              fi
              set_coordinates $COORDINATES
              copy_ini $p
              modify_ini $p
              exe_batch $p
              exe_zip_result $p
          fi
        done <sources_repeat.conf    
    fi
else
    # normal processing
    while read p; do
      if [[ $p != \#* ]]
      then
          echo "Executing: $p"
          create_dir $p
          download_osmdata $p
          extract_osmdata $p
          find_coordinates $p
          copy_ini $p
          modify_ini $p
          exe_truncate_db $p
          exe_read_db $p
          exe_batch $p
          exe_zip_result $p
      fi
    done <sources.conf
fi
