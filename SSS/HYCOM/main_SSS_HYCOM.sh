#!/bin/bash
export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

############################################################################

export HERE=${HOME}/Projects/data/SSS/HYCOM
export tmpDl=/media/taimaz/14TB/.tmp/TS_HYCOM
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/SSS/HYCOM/tiles
# export ncArchive=/media/taimaz/14TB/SSS/HYCOM/nc


# export lastAvailDate=`curl -l "ftp://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts/" | tail -1 | cut -d_ -f4 | sed 's/12$//'`
# lastDlDate=`cat ${HERE}/.lastAvailDate`
##  If the nc directory is present, it means SST already downloaded nc files and then moved them here, so proceed.


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

    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/SSS/HYCOM/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/SSS/HYCOM/dateTimes
EOF
    log "`date` - SSS HYCOM - rsynched - DONE"
    
    rm -r ${HERE}/tiles/
}


if [[ -e ${tmpDl} ]]; then
    log "`date` - SSS HYCOM - STARTED"
    
    # rm -r ${HERE}/nc/
    # mkdir ${HERE}/nc/

    # cd ${HERE}/nc
    # parallel -j 8 'dl {}' ::: {000..180..3}

    
    #########################
    ##  nc -> tiles
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    cd ${tmpDl}
    for f in HYCOM_*.nc; do
	dateHr=`basename $f .nc | cut -d_ -f3-4`
	python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
    done
    log "`date` - SSS HYCOM - Converted"
    
    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Archive
    backJobs &
    
fi
