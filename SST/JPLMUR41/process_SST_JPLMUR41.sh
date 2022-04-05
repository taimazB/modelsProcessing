#!/bin/bash

export HERE=${HOME}/Projects/data/SST/JPLMUR41
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/SST/JPLMUR41/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/SST/JPLMUR41/tiles
export ncArchive=/media/taimaz/14TB/SST/JPLMUR41/nc


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

function backJobs {
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -T -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
	##  Archive nc files
	rsync -auq --timeout=10000 --partial ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/SST/JPLMUR41/lastProcessed
EOF
    
    rm -r ${HERE}/nc
    rm -r ${HERE}/tiles

    # log "`date` - SST JPLMUR41 - rsynched - DONE"
}

##  FUNCTIONS
############################################################################


##################################################
##  nc -> tiles
log "`date` - SST JPLMUR41 Convertion STARTED"
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${HERE}/nc/
python3 ${HERE}/scripts/cnv.py ${lastDlDate}
log "`date` - SST JPLMUR41 Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Archive
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate

