#!/bin/bash

export HERE=${HOME}/Projects/data/Seaice/RTOFS
export remote=taimazhome.ddns.net
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/Seaice/RTOFS/tiles
export ncArchive=/media/taimaz/14TB/Seaice/RTOFS/nc


export lastDlDate=`cat ${HERE}/.lastDlDate`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`

if [[ ! -e ${HERE}/nc ]] || [[ ${lastDlDate} == ${lastProcessDate} ]]; then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function regrid {
    hr=$1
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt rtofs_glo_2ds_f${hr}_ice.nc RTOFS_Seaice_${lastDlDate}_${hr}.nc
    rm rtofs_glo_2ds_f${hr}_ice.nc
}
export -f regrid

function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastDlDate} ${hr}
}
export -f py

function backJobs(){
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Archive processed and original nc files
	# rsync -auq --timeout=10000 ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Seaice/RTOFS/lastProcessed
EOF
    
    rm -r ${HERE}/nc
    rm -r ${HERE}/tiles
    
    # log "`date` - Seaice RTOFS Rsynched DONE."
}

##  FUNCTIONS
############################################################################


rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${HERE}/nc/

log "`date` - Seaice RTOFS Regrid STARTED"
parallel -j 6 "regrid {}" ::: {000..072..1}
log "`date` - Seaice RTOFS Regrid DONE -> Convertion STARTED"
for hr in {000..072..1}; do
    py ${hr}
done
log "`date` - Seaice RTOFS Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Process and backup
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
