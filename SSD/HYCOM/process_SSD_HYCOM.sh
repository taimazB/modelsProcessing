#!/bin/bash

############################################################################

export HERE=${HOME}/Projects/data/SSD/HYCOM
export ncDir=/media/taimaz/14TB/.tmp/TS_HYCOM
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/SSD/HYCOM/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/SSD/HYCOM/tiles

export lastDlDate=`cat ${ncDir}/.lastDlDate`
export lastDlTime=`cat ${ncDir}/.lastDlTime`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`
export lastProcessTime=`cat ${HERE}/.lastProcessTime`

if [[ ! -e ${ncDir} ]] || ([[ ${lastDlDate} == ${lastProcessDate} ]] && [[ ${lastDlTime} == ${lastProcessTime} ]]); then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
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
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/SSD/HYCOM/lastProcessed
EOF

    rm -r ${ncDir}
    rm -r ${HERE}/tiles

    # log "`date` - SSD HYCOM - rsynched - DONE"
}

##  FUNCTIONS
############################################################################


##################################################
##  Calculate density from nc files, then -> tiles
log "`date` - SSD HYCOM Convertion STARTED"
mkdir ${ncDir}/avg
rm -r ${HERE}/tiles
mkdir ${HERE}/tiles/
cd ${ncDir}
for dateHr in `ls HYCOM_TS_*.nc | sed 's/HYCOM_TS_\(.*\)\.nc/\1/'`; do
    python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
done
log "`date` - SSD HYCOM Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Remove empty tile directories
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
echo ${lastDlTime} > ${HERE}/.lastProcessTime
