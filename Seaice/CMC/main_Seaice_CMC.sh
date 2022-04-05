#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_wave/ocean/global/grib2/00/"

############################################################################

export HERE=${HOME}/Projects/data/Seaice/CMC
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Seaice/CMC/tiles
export ncArchive=/media/taimaz/14TB/Seaice/CMC/nc


curl ${ftpLink} > ${HERE}/files
export lastAvailDate=`grep CMC_gdwps_global_ICEC_SFC ${HERE}/files | tail -1 | sed 's/.*CMC_gdwps_global_ICEC_SFC_0_latlon0\.25x0\.25_\(.*\)00_P.*\".*/\1/'`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/files


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    hr=$1
    dlLinkU="${ftpLink}CMC_gdwps_global_ICEC_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.grib2"
    axel -c -a -o ${HERE}/nc ${dlLinkU}
}
export -f dl


function grib2nc {
    hr=$1
    cdo -f nc copy ${HERE}/nc/CMC_gdwps_global_ICEC_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.grib2 ${HERE}/nc/CMC_gdwps_global_ICEC_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.nc
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
ls /media/taimaz/mapTiles/Seaice/CMC/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/Seaice/CMC/dateTimes
EOF
    log "`date` - Seaice CMC - rsynched - DONE"
}


##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]]  &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - Seaice CMC - STARTED"
    rm -r ${HERE}/nc/
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/

    parallel "dl {}" ::: {000..048..1}
    parallel "dl {}" ::: {051..120..3}

    parallel "grib2nc {}" ::: {000..048..1}
    parallel "grib2nc {}" ::: {051..120..3}
    log "`date` - Seaice CMC - Downloaded & grib->nc"
    
    rm ${HERE}/nc/*.grib2

    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    for hr in {000..048..1} {051..120..3}; do
	py ${hr}
    done
    log "`date` - Seaice CMC - Converted"
    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    #####################################################
    ##  Archive
    backJobs &

    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
