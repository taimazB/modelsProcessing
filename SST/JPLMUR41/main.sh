#!/bin/bash
mainLink='https://podaac-opendap.jpl.nasa.gov/opendap/hyrax/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/'

############################################################################

HERE=${HOME}/Projects/OceanGNS/data/SST/JPLMUR41
archive=/media/taimaz/14TB/SST/JPLMUR41/

year=`date +%Y`
lastAvailDay=`printf %03d $(curl https://podaac-opendap.jpl.nasa.gov/opendap/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/${year}/ | grep "contents.html" | tail -1 | sed 's,<a href="\(.*\)/contents.*,\1,' | xargs)`
lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
month=`date -d "${lastAvailDate}" +%m`
day=`date -d "${lastAvailDate}" +%d`
lastDlDate=`cat ${HERE}/.lastAvailDate`

# year=2021
# lastAvailDay=130
# lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
# month=`date -d "${lastAvailDate}" +%m`
# day=`date -d "${lastAvailDate}" +%d`

if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_09.nc ${mainLink}${year}/${lastAvailDay}/${year}${month}${day}090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc


    ##################################################
    ##  nc -> tiles
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    python3 ${HERE}/scripts/cnv_tile.py ${lastAvailDate}
        
    
    ##################################################
    ##  Copy to server
    ##  Overwrite what is already there
    rsync -aurz ${HERE}/tiles taimaz@159.203.6.104:/mnt/data/models/SST/JPLMUR41/

    
    ##################################################
    ##  Backup
    cd ${HERE}
    rsync -aur ${HERE}/tiles ${archive}/
    rm -r ${HERE}/tiles/ &
    mv ${HERE}/nc/* ${archive}/nc/
    rm -r ${HERE}/nc/ &
    
    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
