#!/bin/bash
# ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/nesdisVHNnoaa20chlaDaily.nc?chlor_a'
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/nesdisVHNnoaaSNPPnoaa20chlaGapfilledDaily.nc?chlor_a'

############################################################################

export HERE=${HOME}/Projects/data/Chlorophyll/NESDIS
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Chlorophyll/NESDIS/tiles
export ncArchive=/media/taimaz/14TB/Chlorophyll/NESDIS/nc


dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(1):1:(0)][(0):1:(1)]"
axel -a -n 50 -o ${HERE}/tmp.nc ${dlLink}
lastAvailDate=`ncdump -h ${HERE}/tmp.nc | grep time_coverage_start | sed 's/.*time_coverage_start = "// ; s/T.*//'`
lastAvailDate=`date -d "${lastAvailDate}" +%Y%m%d`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/tmp.nc


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
	##  Archive nc files
	rsync -auq --timeout=10000 --partial ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
    done
    log "`date` - Chlorophyll NESDIS - rsynched - DONE"
}


if [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - Chlorophyll NESDIS - STARTED"
    rm -r ${HERE}/nc/ ${HERE}/tiles/
    
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(85):1:(-85)][(-179.99):1:(179.99)]"
    axel -a -n 50 -o ${HERE}/nc/NESDIS_Chlorophyll_${lastAvailDate}.nc ${dlLink}
    log "`date` - Chlorophyll NESDIS - Downloaded"

    
    ##################################################
    ##  nc -> tiles
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate}
    log "`date` - Chlorophyll NESDIS - Converted"

    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Archive
    backJobs &

    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
