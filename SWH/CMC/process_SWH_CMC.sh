#!/bin/bash

export HERE=${HOME}/Projects/data/SWH/CMC
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/SWH/CMC/tiles
export ncArchive=/media/taimaz/14TB/SWH/CMC/nc


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

function grib2nc {
    hr=$1
    cdo -f nc copy ${HERE}/nc/CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.grib2 ${HERE}/nc/CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.nc
}
export -f grib2nc

function py {
    hr=$1
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr}
}
export -f py

function backJobs {
    # Correct nc filenames date and time
    cd ${HERE}/nc
    for f in CMC_*.nc; do
	hr=`basename $f .nc | cut -d_ -f9 | sed 's/P//'`
	HR=`echo ${hr} | sed 's/^0*//'`
	day=$((HR/24))
	newDate=`date -d "${lastAvailDate} +${day} day" +%Y%m%d`
	newHr=`printf %03d $((HR-day*24))`
	newFileName=`echo $f | sed "s/${lastAvailDate}/${newDate}/ ; s/P${hr}/P${newHr}/"`
	mv $f ${newFileName}
    done


    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -T -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
	##  Archive nc files
	rsync -auq --partial --timeout=10000 ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/SWH/CMC/lastProcessed
EOF

    rm -r ${HERE}/nc
    
    # log "`date` - SWH CMC Rsync DONE."
}

##  FUNCTIONS
############################################################################


log "`date` - SWH CMC grib to nc STARTED"
parallel "grib2nc {}" ::: {000..048..1}
parallel "grib2nc {}" ::: {051..120..3}
log "`date` - SWH CMC grib to nc DONE"
rm ${HERE}/nc/*.grib2


##################################################
##  nc -> tiles
log "`date` - SWH CMC Convertion STARTED"
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
for hr in {000..048..1} {051..120..3}; do
    py ${hr}
done
log "`date` - SWH CMC Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Archive
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcesslDate
