#!/bin/bash
export mainLink='https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/sst'

############################################################################

field=SST
model=Coraltemp
export HERE=${HOME}/Projects/data/${field}/${model}
export ncDir=/media/taimaz/14TB/.tmp/${model}
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/${field}/${model}/tiles

if [[ -e ${ncDir} ]]; then
    exit
fi

export lastAvailDate=`curl https://www.ncei.noaa.gov/thredds-ocean/catalog/crw/5km/v3.1/nc/v1.0/daily/sst/2022/catalog.html | grep coraltemp | tail -1 | sed 's,.*coraltemp_v3\.1_\(.*\)\.nc.*,\1,'`
export year=${lastAvailDate:0:4}
lastDlDate=`cat ${HERE}/.lastDlDate`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl(){
    axel -a -n 50 -o Coraltemp_SST_${lastAvailDate}.nc "${mainLink}/${year}/coraltemp_v3.1_${lastAvailDate}.nc"
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    mkdir ${ncDir}/
    cd ${ncDir}

    log "`date` - SST Coraltemp Download STARTED"
    dl
    log "`date` - SST Coraltemp Download DONE"
    
    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    echo ${lastAvailDate} > ${ncDir}/.lastDlDate ## For others
fi
