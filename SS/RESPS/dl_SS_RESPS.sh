#!/bin/bash
export mainLink='https://dd.meteo.gc.ca/model_resps/atlantic-nw/9km/00/'

############################################################################

export HERE=${HOME}/Projects/data/SS/RESPS

if [[ -e ${HERE}/nc ]]; then
    exit
fi

export lastAvailDate=`curl ${mainLink} | grep ETAS | tail -1 | sed 's,.*<a href="\(........\)T00Z.*,\1,'`
lastDlDate=`cat ${HERE}/.lastDlDate`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    dlLink="${mainLink}${lastAvailDate}T00Z_MSC_RESPS-Atlantic-North-West_ETAS_Sfc_LatLon0.083_PT${hr}H.nc"
    wget -O ${HERE}/nc/RESPS_SS_${lastAvailDate}_${hr}.nc ${dlLink}
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - SS RESPS Download STARTED"
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    parallel 'dl {}' ::: {000..384}
    log "`date` - SS RESPS Download DONE"


    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    
fi
