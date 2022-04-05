#!/bin/bash

export HERE=${HOME}/Projects/data/SHF/HYCOM
export ncDir=/media/taimaz/14TB/.tmp/SUR_HYCOM
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/SHF/HYCOM/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/SHF/HYCOM/tiles


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

function backJobs(){
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/SHF/HYCOM/lastProcessed
EOF
    
    rm -r ${ncDir}
    rm -r ${HERE}/tiles
    
    # log "`date` - SHF HYCOM Rsync DONE."
}

##  FUNCTIONS
############################################################################


##################################################
##  nc -> tiles    echo -e "\tProcessing ..."
log "`date` - SHF HYCOM Convertion STARTED"
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${ncDir}
for f in HYCOM_*.nc; do
    dateHr=`basename $f .nc | cut -d_ -f3-4`
    python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
done
log "`date` - SHF HYCOM Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Process and backup
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
echo ${lastDlTime} > ${HERE}/.lastProcessTime
