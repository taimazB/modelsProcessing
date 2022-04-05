#!/bin/bash
mainLink='https://podaac-opendap.jpl.nasa.gov/opendap/hyrax/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/'

############################################################################

export HERE=${HOME}/Projects/data/SST/JPLMUR41

if [[ -e ${HERE}/nc ]]; then
    exit
fi

year=`date +%Y`
lastAvailDay=`curl https://podaac-opendap.jpl.nasa.gov/opendap/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/${year}/ | grep "contents.html" | tail -1 | sed 's,<a href="\(.*\)/contents.*,\1,' | xargs`
lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
month=`date -d "${lastAvailDate}" +%m`
day=`date -d "${lastAvailDate}" +%d`
lastDlDate=`cat ${HERE}/.lastDlDate`

# year=2021
# lastAvailDay=`printf %03d $1`
# lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
# month=`date -d "${lastAvailDate}" +%m`
# day=`date -d "${lastAvailDate}" +%d`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - SST JPLMUR41 Download STARTED"
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    # axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_09.nc ${mainLink}${year}/${lastAvailDay}/${year}${month}${day}090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc
    wget -O ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_09.nc ${mainLink}${year}/${lastAvailDay}/${year}${month}${day}090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc
    log "`date` - SST JPLMUR41 Download DONE"


    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    
fi
