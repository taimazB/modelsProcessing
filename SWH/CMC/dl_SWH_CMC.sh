#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_wave/ocean/global/grib2/00/"

############################################################################

export HERE=${HOME}/Projects/data/SWH/CMC

if [[ -e ${HERE}/nc ]]; then
    exit
fi

curl ${ftpLink} > ${HERE}/files
export lastAvailDate=`grep CMC_gdwps_global_HTSGW_SFC ${HERE}/files | tail -1 | sed 's/.*CMC_gdwps_global_HTSGW_SFC_0_latlon0\.25x0\.25_\(.*\)00_P.*\".*/\1/'`
lastDlDate=`cat ${HERE}/.lastDlDate`
rm ${HERE}/files


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    hr=$1
    dlLinkU="${ftpLink}CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.grib2"
    axel -c -a -o ${HERE}/nc ${dlLinkU}
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/

    log "`date` - SWH CMC Download STARTED"
    parallel "dl {}" ::: {000..048..1}
    parallel "dl {}" ::: {051..120..3}
    log "`date` - SWH CMC Download DONE"
   
    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    
fi
