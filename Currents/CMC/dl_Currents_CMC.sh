#!/bin/bash
export ftpLink="https://dd.weather.gc.ca/model_gem_regional/coupled/gulf_st-lawrence/grib2/"

############################################################################

export HERE=${HOME}/Projects/data/Currents/CMC

if [[ -e ${HERE}/nc ]]; then
    exit
fi

rm ${HERE}/availDates
# for modelHr in 00 06 12 18; do
for modelHr in 00; do
    curl ${ftpLink}${modelHr}/048/ > ${HERE}/files
    lastAvailDate=$(grep CMC_coupled-rdps-stlawrence-ocean files | tail -1 | sed 's/.*href=\"CMC_coupled-rdps-stlawrence-ocean_latlon0\.02x0\.03_\(.*\)_P048.*\".*/\1/')
    echo $lastAvailDate >> ${HERE}/availDates
done
export lastAvailDate=`sort -g ${HERE}/availDates | tail -1 | cut -c1-8`
# export lastAvailHour=`sort -g ${HERE}/availDates | tail -1 | cut -c9-10`
export lastAvailHour=00
lastDlDate=$(cat ${HERE}/.lastDlDate)
rm ${HERE}/files ${HERE}/availDates


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    dlLink="${ftpLink}${lastAvailHour}/${hr}/CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}${lastAvailHour}_P${hr}.grib2"
    axel -c -a -n 50 -o ${HERE}/nc/ ${dlLink}
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    
    log "`date` - Currents CMC Download STARTED"
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    parallel -j 4 "dl {}" ::: {001..048..1}
    log "`date` - Currents CMC Download DONE"

    
    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    
fi
