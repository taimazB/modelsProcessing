#!/bin/bash
export catalogLink="https://thredds.met.no/thredds/catalog/fou-hi/barents_eps_zdepth/catalog.html"
export dlLink="https://thredds.met.no/thredds/fileServer/fou-hi/barents_eps_zdepth/"

############################################################################

export field=Seaice
export model=Barents
export HERE=${HOME}/Projects/data/${field}/${model}
export ncDir=/media/taimaz/14TB/.tmp/${model}

if [[ -e ${ncDir} ]]; then
    exit
fi

export lastAvailDate=`curl ${catalogLink} | grep barents | grep FC | cut -d ">" -f1 | sed 's,.*/barents_zdepth_\(.*\)T00.*,\1,'`
lastDlDate=`cat ${HERE}/.lastDlDate`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    axel -c -a -n 50 -T 60 -o ${ncDir}/ "${dlLink}barents_zdepth_${lastAvailDate}T00Zm00_FC.nc"
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    mkdir ${ncDir}
    cd ${ncDir}

    log "`date` - dl S ${field} ${model}"
    dl
    log "`date` - dl E ${field} ${model}"

    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    cp ${HERE}/.lastDlDate ${ncDir}  ##  For others
    
fi
