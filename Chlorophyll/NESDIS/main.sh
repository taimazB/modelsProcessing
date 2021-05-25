#!/bin/bash
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/nesdisVHNnoaa20chlaDaily.nc?chlor_a'

############################################################################

HERE=${HOME}/Projects/OceanGNS/data/Chlorophyll/NESDIS
archive=/media/taimaz/14TB/Chlorophyll/NESDIS/

# export http_proxy='158.199.141.158:8083'

rm ${HERE}/tmp.nc
dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(1):1:(0)][(0):1:(1)]"
axel -a -n 50 -o ${HERE}/tmp.nc ${dlLink}
lastAvailDate=`ncdump -h ${HERE}/tmp.nc | grep time_coverage_start | sed 's/.*time_coverage_start = "// ; s/T.*//'`
lastAvailDate=`date -d "${lastAvailDate}" +%Y%m%d`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/tmp.nc

# lastAvailDate=$1
    
if [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(85):1:(-85)][(-179.99):1:(179.99)]"
    axel -a -n 50 -o ${HERE}/nc/NESDIS_Chlorophyll_${lastAvailDate}_12.nc ${dlLink}

    
    ##################################################
    ##  nc -> tiles
    mkdir ${HERE}/tiles/
    python3 ${HERE}/scripts/cnv_tile.py ${lastAvailDate}

    
    ##################################################
    ##  Copy tiles to server
    rsync -aurz ${HERE}/tiles taimaz@159.203.6.104:/mnt/data/models/Chlorophyll/NESDIS/

    
    ##################################################
    ##  Backup
    cd ${HERE}
    rsync -aur ${HERE}/tiles ${archive}/
    rm -r ${HERE}/tiles &
    mv ${HERE}/nc/* ${archive}/nc
    rm -r ${HERE}/nc/
    
    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
