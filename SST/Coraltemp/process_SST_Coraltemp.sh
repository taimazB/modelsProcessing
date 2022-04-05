#!/bin/bash

field=SST
model=Coraltemp
export HERE=${HOME}/Projects/data/${field}/${model}
export ncDir=/media/taimaz/14TB/.tmp/${model}
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/SST/HYCOM/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/${field}/${model}/tiles

export lastDlDate=`cat ${ncDir}/.lastDlDate`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`

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
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/${field}/${model}/lastProcessed
EOF
    
    # rm -r ${ncDir}  ##  Do NOT remove here.
    rm -r ${HERE}/tiles/
}

##  FUNCTIONS
############################################################################


##################################################
##  nc -> tiles
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${ncDir}/

log "`date` SST HYCOM Convertion STARTED"
python3 ${HERE}/scripts/cnv.py ${lastDlDate} ${HERE}
log "`date` SST HYCOM Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Process and backup
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
