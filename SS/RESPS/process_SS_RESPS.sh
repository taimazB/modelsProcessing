#!/bin/bash

export HERE=${HOME}/Projects/data/SS/RESPS
export remote=taimazhome.ddns.net
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/SS/RESPS/tiles
# export ncArchive=/media/taimaz/14TB/SS/RESPS/nc


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
	# rsync -auq --timeout=10000 --partial ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
    done

    rm -r ${HERE}/nc
    rm -r ${HERE}/tiles

    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/SS/RESPS/lastProcessed
EOF
    
    # log "`date` - SS RESPS Rsync DONE"
}

##  FUNCTIONS
############################################################################


##################################################
##  nc -> tiles
log "`date` - SS RESPS Convertion STARTED"
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${HERE}/nc/
for f in *.nc; do
    hr=`basename $f .nc | cut -d_ -f4`
    python3 ${HERE}/scripts/cnv.py ${lastDlDate} ${hr}
done
log "`date` - SS RESPS Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Archive
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
