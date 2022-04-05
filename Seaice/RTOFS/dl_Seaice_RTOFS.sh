#!/bin/bash
export mainLink="https://nomads.ncep.noaa.gov/pub/data/nccf/com/rtofs/prod/"

############################################################################

export HERE=${HOME}/Projects/data/Seaice/RTOFS

if [[ -e ${HERE}/nc ]]; then
    exit
fi

export lastAvailDate=`curl ${mainLink} | grep rtofs | sed '$!d' | cut -d\" -f2 | sed 's,rtofs\.\(.*\)/,\1,'`
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
    dlLink="${mainLink}rtofs.${lastAvailDate}/rtofs_glo_2ds_f${hr}_ice.nc"
    # axel -c -a -n 50 -o ${HERE}/nc/ ${dlLink}
    wget ${dlLink}
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - MLD RTOFS - STARTED"
    mkdir ${HERE}/nc
    cd ${HERE}/nc/

    log "`date` - Seaice RTOFS Download STARTED"
    parallel "dl {}" ::: {000..072..1}
    noOfFiles=`ls | wc -l`
    if [[ ${noOfFiles} -gt 0 ]]; then
	for f in *; do
	    ncdump -h $f > /dev/null 2>&1
	    if [[ $? -ne 0 ]]; then
		log "`date` - Seaice RTOFS Download FAILED"
		rm -r ${HERE}/nc
		exit
	    fi
	done
    else
	log "`date` - Seaice RTOFS Download FAILED"
	rm -r ${HERE}/nc
	exit
    fi
	
    log "`date` - Seaice RTOFS Download DONE"


    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    
fi
