#!/bin/bash
ftpLink='https://oceandata.sci.gsfc.nasa.gov/opendap/MODISA/L3SMI/'

############################################################################

export HERE=${HOME}/Projects/data/Chlorophyll/MODIS


lastDlDOY=`cat ${HERE}/.lastDlDOY`
year=`date +%Y`
DOY=$((lastDlDOY+1))
DOY3=`printf %03d ${DOY}`
dlLink="${ftpLink}${year}/${DOY3}/A${year}${DOY3}.L3m_DAY_CHL_chlor_a_4km.nc.nc4?'"


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

##  FUNCTIONS
############################################################################


wget -O ${HERE}/tmp.nc ${dlLink}
if [[ $? -eq 0 ]]; then
    log "`date` - Chlorophyll MODIS Download DONE"
    
    date=`date -d "${year}0101 +$((DOY-1)) days" +%Y%m%d`

    rm -r ${HERE}/nc/
    mkdir ${HERE}/nc/
    mv ${HERE}/tmp.nc ${HERE}/nc/MODIS_Chlorophyll_${date}.nc
    
    echo ${DOY} > ${HERE}/.lastDlDOY
else
    rm ${HERE}/tmp
fi
