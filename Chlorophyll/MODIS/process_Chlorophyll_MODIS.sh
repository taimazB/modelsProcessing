#!/bin/bash

export HERE=${HOME}/Projects/data/Chlorophyll/MODIS
export remote=taimazhome.ddns.net
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/Chlorophyll/MODIS/tiles


export lastDlDOY=`cat ${HERE}/.lastDlDOY`
export lastProcessDOY=`cat ${HERE}/.lastProcessDOY`

if [[ ! -e ${HERE}/nc ]] || [[ ${lastDlDOY} == ${lastProcessDOY} ]]; then
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
	# rsync -auq --timeout=10000 --partial ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Chlorophyll/MODIS/lastProcessed
EOF
    
    rm -r ${HERE}/nc/
    rm -r ${HERE}/tiles/

    # log "`date` - Chlorophyll MODIS - rsynched - DONE"
}


##################################################
##  nc -> tiles
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${HERE}/nc/
year=`date +%Y`
date=`date -d "${year}0101 +$((lastDlDOY-1)) days" +%Y%m%d`
python3 ${HERE}/scripts/cnv.py ${date}
log "`date` - Chlorophyll MODIS - Converted"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete

    
##################################################
##  Archive
backJobs &

    
echo ${lastDlDOY} > ${HERE}/.lastProcessDOY
