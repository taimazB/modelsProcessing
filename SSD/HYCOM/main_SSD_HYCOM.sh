#!/bin/bash

############################################################################

export HERE=${HOME}/Projects/data/SSD/HYCOM
export tmpDl=/media/taimaz/14TB/.tmp/TS_HYCOM
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/SSD/HYCOM/tiles


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function backJobs {
    cd ${HERE}
    
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -T -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/SSD/HYCOM/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/SSD/HYCOM/dateTimes
EOF
    log "`date` - SSD HYCOM - rsynched - DONE"
    
    rm -r ${HERE}/tiles
}


if [[ -e ${tmpDl} ]]; then
    log "`date` - SSD HYCOM - STARTED"
    
    ##################################################
    ##  Calculate density from nc files, then -> tiles
    rm -r ${HERE}/tiles
    mkdir ${HERE}/tiles/
    
    cd ${tmpDl}
    for dateHr in `ls HYCOM_TS_*.nc | sed 's/HYCOM_TS_\(.*\)\.nc/\1/'`; do
	python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
    done
    rm -r ${tmpDl}  ##  Remove as it's not needed anymore
    log "`date` - SSD HYCOM - Converted"
    
    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Remove empty tile directories
    backJobs &
    
fi
