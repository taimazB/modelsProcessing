#!/bin/bash

export HERE=${HOME}/Projects/data/Currents/Doppio
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/Currents/Doppio/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/Currents/Doppio/tiles
export pathPlanning=${remote}:/home/taimaz/Projects/server/public/pathPlanning/gnt/Datasets/Doppio/forecast
# export ncArchive=/media/taimaz/14TB/Currents/Doppio/nc


export today=`date +%Y%m%d`
export lastDlDateTime=`cat ${HERE}/.lastDlDateTime`
export lastProcessDateTime=`cat ${HERE}/.lastProcessDateTime`

if [[ ! -e ${HERE}/nc ]] || [[ ${lastDlDateTime} ==  ${lastProcessDateTime} ]]; then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function regrid {
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${HERE}/nc/tmp.nc ${HERE}/nc/Doppio_Currents_${today}.nc
}
export -f regrid

function backJobs(){
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    # cd ${HERE}/nc/avg
    # cdo -O ensmean ${HERE}/nc/avg/RIOPS_Currents_avgDepth_${lastAvailDate}_*.nc ${HERE}/nc/avg/RIOPS_Currents_avgDepth_avgTime.nc
    

    #####################################################
    ##  Archive
    cd ${HERE}
    rm ${HERE}/nc/tmp.nc ${HERE}/nc/Doppio_Currents_${today}.nc
    
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
    ##  Copy processed nc files to path planning server
	rsync -auq --partial --timeout=10000 --delete -e 'ssh -p 4412' ${HERE}/nc/ ${pathPlanning}
	resync=`echo "${resync} + $?" | bc`
	##  Archive processed and original nc files
	# rsync -auq --timeout=10000 ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Currents/Doppio/lastProcessed
EOF

    # rm -r ${HERE}/nc
    # rm -r ${HERE}/tiles

    # log "`date` - Currents Doppio Rsync DONE."
}


##  FUNCTIONS
############################################################################


rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${HERE}/nc/

log "`date` - Currents Doppio Regrid STARTED"
regrid
log "`date` - Currents Doppio Regrid DONE -> Convertion STARTED"
python3 ${HERE}/scripts/cnv.py ${today}
log "`date` - Currents Doppio Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Process and backup
backJobs &


echo ${lastDlDateTime} > ${HERE}/.lastProcessDateTime
