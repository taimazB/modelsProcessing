#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_riops/netcdf/forecast/polar_stereographic/3d/00/"

############################################################################

export HERE=${HOME}/Projects/data/Currents/RIOPS

if [[ -e ${HERE}/nc ]]; then
    exit
fi

curl ${ftpLink}048/ > ${HERE}/files
export lastAvailDate=`grep MSC_RIOPS_VOMECRTY_DBS-all_PS5km ${HERE}/files | tail -1 | sed 's/.*href=\"\(.*\)T00Z.*\".*/\1/'`
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
    echo "##  ${lastAvailDate}_${hr}"
    dlLinkU="${ftpLink}${hr}/${lastAvailDate}T00Z_MSC_RIOPS_VOZOCRTX_DBS-all_PS5km_P${hr}.nc"
    # axel -c -a -n 50 -o ${HERE}/nc/ ${dlLinkU}
    wget ${dlLinkU}
    
    dlLinkV="${ftpLink}${hr}/${lastAvailDate}T00Z_MSC_RIOPS_VOMECRTY_DBS-all_PS5km_P${hr}.nc"
    # axel -c -a -n 50 -o ${HERE}/nc/ ${dlLinkV}
    wget ${dlLinkV}
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - Currents RIOPS Download STARTED"
    mkdir ${HERE}/nc
    cd ${HERE}/nc/
    parallel -j 4 "dl {}" ::: {000..047..3}
    log "`date` - Currents RIOPS Download DONE"


    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    
fi
