#!/bin/bash
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/nesdisVHNnoaa20chlaDaily.nc?chlor_a'

############################################################################

HERE=/home/taimaz/Projects/mapBoxData/Chlorophyll/NESDIS/

# export http_proxy='158.199.141.158:8083'

rm ${HERE}/nc/tmp.nc
dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(1):1:(0)][(0):1:(1)]"
axel -a -n 50 -o ${HERE}/nc/tmp.nc ${dlLink}
lastAvailDate=`ncdump -h ${HERE}/nc/tmp.nc | grep time_coverage_start | sed 's/.*time_coverage_start = "// ; s/T.*//'`
lastAvailDate=`date -d "${lastAvailDate}" +%Y%m%d`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/nc/tmp.nc

    
if [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    cd ${HERE}/nc/
    dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(80):1:(-80)][(-179.99):1:(179.99)]"
    axel -a -n 50 -o ${HERE}/nc/NESDIS_Chlorophyll_${lastAvailDate}_12.nc ${dlLink}

    ##  nc -> png
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate}

    ##  png -> jpg
    cd ${HERE}/png/
    convert ${HERE}/png/NESDIS_Chlorophyll_${lastAvailDate}_12.png ${HERE}/jpg/higRes/NESDIS_Chlorophyll_${lastAvailDate}_12.jpg
    convert -resize 10% ${HERE}/png/NESDIS_Chlorophyll_${lastAvailDate}_12.png ${HERE}/jpg/lowes/NESDIS_Chlorophyll_${lastAvailDate}_12.jpg

    
    ##################################################
    ##  Copy jpg's to server
#     ssh taimaz@159.203.6.104 <<EOF
# rm /home/taimaz/web/public/models/HYCOM/UV/jpg/*
# EOF
    # rsync -aurz ${HERE}/jpg taimaz@159.203.6.104:/mnt/external/models/NESDIS/Chlorophyll/

    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
