#!/bin/bash
ftpLink='https://oceandata.sci.gsfc.nasa.gov/opendap/MODISA/L3SMI/'

############################################################################

export HERE=${HOME}/Projects/data/Chlorophyll/MODIS
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Chlorophyll/MODIS/tiles
# export ncArchive=/media/taimaz/14TB/Chlorophyll/MODIS/nc


lastDlDate=`cat ${HERE}/.lastDlDate`
year=`date +%Y`
DOY=$((lastDlDOY+1))
DOY3=`printf %03d ${DOY}`
dlLink="${ftpLink}${year}/${DOY3}/A${year}${DOY3}.L3m_DAY_CHL_chlor_a_4km.nc.nc4?'"


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
	# rsync -auq --timeout=10000 --partial ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/Chlorophyll/MODIS/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/Chlorophyll/MODIS/dateTimes
EOF
    log "`date` - Chlorophyll MODIS - rsynched - DONE"
}


wget -O ${HERE}/tmp.nc ${dlLink}
if [[ $? -eq 0 ]]; then

    log "`date` - Chlorophyll MODIS - STARTED"
    log "`date` - Chlorophyll MODIS - Downloaded"
    
    date=`date -d "${year}0101 +$((DOY-1)) days" +%Y%m%d`

    rm -r ${HERE}/nc/
    mkdir ${HERE}/nc/
    mv ${HERE}/tmp.nc ${HERE}/nc/MODIS_Chlorophyll_${date}.nc
    cd ${HERE}/nc/

    
    ##################################################
    ##  nc -> tiles
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    python3 ${HERE}/scripts/cnv.py ${date}
    log "`date` - Chlorophyll MODIS - Converted"

    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Archive
    backJobs &

    
    echo ${DOY} > ${HERE}/.lastDlDOY
    
fi
