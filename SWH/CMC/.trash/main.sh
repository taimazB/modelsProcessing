#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_wave/ocean/global/grib2/00/"

############################################################################

export HERE=${HOME}/Projects/mapBoxData/SWH/CMC


curl ${ftpLink} > ${HERE}/files
export lastAvailDate=`grep CMC_gdwps_global_HTSGW_SFC ${HERE}/files | tail -1 | sed 's/.*CMC_gdwps_global_HTSGW_SFC_0_latlon0\.25x0\.25_\(.*\)00_P.*\".*/\1/'`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/files


############################################################################
##  FUNCTIONS

function dl {
    hr=$1
    dlLinkU="${ftpLink}CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.grib2"
    axel -c -a -o ${HERE}/nc ${dlLinkU}
}
export -f dl


function grib2nc {
    hr=$1
    cdo -f nc copy ${HERE}/nc/CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.grib2 ${HERE}/nc/CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_${lastAvailDate}00_P${hr}.nc
}
export -f grib2nc


function py {
    hr=$1
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr}
}
export -f py

##  FUNCTIONS
############################################################################



if [[ -n ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    
    cd ${HERE}/nc/
    rm ${HERE}/nc/*.nc
    rm ${HERE}/png/*

    parallel "dl {}" ::: {000..048..1}
    parallel "dl {}" ::: {051..120..3}

    parallel "grib2nc {}" ::: {000..048..1}
    parallel "grib2nc {}" ::: {051..120..3}

    rm ${HERE}/nc/*.grib2

    parallel "py {}" ::: {000..048..1}  ## Convert to mercator; image saving
    parallel "py {}" ::: {051..120..3}  ## Convert to mercator; image saving


    ##################################################
    ##  Convert png to jpg  (png's are big)
    cd ${HERE}/png/
    ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
    # mv ${HERE}/png/*.png /media/taimaz/f74aa447-fe2f-44af-8ee6-3bb554756a5d/taimaz/CMC/SWH/png/

    
    ##################################################
    ##  Copy jpg's to server
#     ssh taimaz@159.203.6.104 << EOF
# rm /home/taimaz/web/public/models/RIOPS/Currents/jpg/*
# EOF
    # rsync -aurz ${HERE}/jpg taimaz@159.203.6.104:/mnt/external/models/SWH/CMC/ &

    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
