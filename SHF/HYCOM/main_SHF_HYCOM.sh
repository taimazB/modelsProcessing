#!/bin/bash
# export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

############################################################################

export HERE=${HOME}/Projects/data/SHF/HYCOM
export tmpDl=/media/taimaz/14TB/.tmp/SUR_HYCOM
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/SHF/HYCOM/tiles


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
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
ls /media/taimaz/mapTiles/SHF/HYCOM/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/SHF/HYCOM/dateTimes
EOF
    
    log "`date` - SHF HYCOM - rsynched - DONE"
}


##  FUNCTIONS
############################################################################


if [[ -e ${tmpDl} ]]; then
    log "`date` - SHF HYCOM - STARTED"

    ##################################################
    ##  nc -> tiles    echo -e "\tProcessing ..."
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    cd ${tmpDl}
    for f in HYCOM_*.nc; do
	dateHr=`basename $f .nc | cut -d_ -f3-4`
	python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
    done
    rm -r ${tmpDl}  ##  Remove as it's not needed anymore
    log "`date` - SHF HYCOM - Converted"
    

    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Process and backup
    backJobs &

fi
