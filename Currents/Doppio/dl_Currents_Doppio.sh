#!/bin/bash
export ftpLink='https://tds.marine.rutgers.edu/thredds/ncss/roms/doppio/2017_da/his/History_Best?var=ubar_eastward&var=vbar_northward&horizStride=1&timeStride=1&vertCoord=&accept=netcdf4'

############################################################################

export HERE=${HOME}/Projects/data/Currents/Doppio

if [[ -e ${HERE}/nc ]]; then
    exit
fi

today=`date +%Y%m%d`
startDate=`date +%Y-%m-%d`
endDate=`date -d "+10 days" +%Y-%m-%d`
dlLink="${ftpLink}&time_start=${startDate}T00%3A00%3A00Z&time_end=${endDate}T23%3A00%3A00Z"
axel -a -n 50 -o ${HERE}/tmp.nc "${dlLink}"
lastAvailDate=`cdo info ${HERE}/tmp.nc | grep -v Date | tail -1 | awk '{print $3}'`
lastAvailTime=`cdo info ${HERE}/tmp.nc | grep -v Date | tail -1 | awk '{print $4}'`
lastAvailDateTime="${lastAvailDate}_${lastAvailTime}"
lastDlDateTime=`cat ${HERE}/.lastDlDateTime`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDateTime} ]] && [[ ${lastAvailDateTime} != ${lastDlDateTime} ]]; then

    log "`date` - Currents Doppio Download DONE"
    mkdir ${HERE}/nc
    mv ${HERE}/tmp.nc ${HERE}/nc/
    echo ${lastAvailDateTime} > ${HERE}/.lastDlDateTime
    
else
    rm ${HERE}/tmp.nc
fi
