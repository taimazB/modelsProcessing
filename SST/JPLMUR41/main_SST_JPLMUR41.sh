#!/bin/bash
mainLink='https://podaac-opendap.jpl.nasa.gov/opendap/hyrax/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/'

############################################################################

export HERE=${HOME}/Projects/data/SST/JPLMUR41
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/SST/JPLMUR41/tiles
export ncArchive=/media/taimaz/14TB/SST/JPLMUR41/nc


year=`date +%Y`
lastAvailDay=`curl https://podaac-opendap.jpl.nasa.gov/opendap/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/${year}/ | grep "contents.html" | tail -1 | sed 's,<a href="\(.*\)/contents.*,\1,' | xargs`
lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
month=`date -d "${lastAvailDate}" +%m`
day=`date -d "${lastAvailDate}" +%d`
lastDlDate=`cat ${HERE}/.lastAvailDate`

# year=2021
# lastAvailDay=`printf %03d $1`
# lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
# month=`date -d "${lastAvailDate}" +%m`
# day=`date -d "${lastAvailDate}" +%d`


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

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/SST/JPLMUR41/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/SST/JPLMUR41/dateTimes
EOF
    log "`date` - SST JPLMUR41 - rsynched - DONE"
}


if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    log "`date` - SST JPLMUR41 - STARTED"
    
    rm -r ${HERE}/nc/ ${HERE}/tiles/

    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_09.nc ${mainLink}${year}/${lastAvailDay}/${year}${month}${day}090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc
    log "`date` - SST JPLMUR41 - Downloaded"
    

    ##################################################
    ##  nc -> tiles
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate}
    log "`date` - SST JPLMUR41 - Converted"
        
    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete


    ##################################################
    ##  Archive
    backJobs &
    
    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
