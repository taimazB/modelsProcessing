#!/bin/bash
export catalogLink="https://thredds.met.no/thredds/catalog/fou-hi/norkyst800m-1h/catalog.html"
export dlLink="https://thredds.met.no/thredds/fileServer/fou-hi/norkyst800m-1h/"

############################################################################

export field=Currents
export model=NorKyst800m
export HERE=${HOME}/Projects/data/${field}/${model}
export ncDir=/media/taimaz/14TB/.tmp/${model}

if [[ -e ${ncDir} ]]; then
    exit
fi

export lastAvailDate=`curl ${catalogLink} | grep 'NorKyst-800m_ZDEPTHS_his.fc' | cut -d ">" -f1 | sed 's,.*/NorKyst-800m_ZDEPTHS_his\.fc\.\(.*\)00\.nc.*,\1,'`
lastDlDate=`cat ${HERE}/.lastDlDate`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    axel -c -a -n 50 -T 60 -o ${ncDir}/ "${dlLink}NorKyst-800m_ZDEPTHS_his.fc.${lastAvailDate}00.nc"
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
