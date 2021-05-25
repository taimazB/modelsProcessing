#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_wave/ocean/global/grib2/00/"

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/SWH/CMC
export archive=/media/taimaz/14TB/SWH/CMC/


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
    python3 ${HERE}/scripts/cnv_tile.py ${lastAvailDate} ${hr}
}
export -f py


##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    mkdir ${HERE}/nc/
    cd ${HERE}/nc/

    parallel "dl {}" ::: {000..048..1}
    parallel "dl {}" ::: {051..120..3}

    parallel "grib2nc {}" ::: {000..048..1}
    parallel "grib2nc {}" ::: {051..120..3}

    rm ${HERE}/nc/*.grib2

    parallel -j 7 "py {}" ::: {000..048..1}  ## Convert to mercator; image saving
    parallel -j 6 "py {}" ::: {051..120..3}  ## Convert to mercator; image saving

    
    ##################################################
    ##  Copy tiles to server
    rsync -aurz ${HERE}/tiles taimaz@159.203.6.104:/mnt/data/models/SWH/CMC/


    ##################################################
    ##  Backup nc files
    cd ${HERE}
    rsync -aur ${HERE}/tiles ${archive} || exit 1
    rm -r ${HERE}/tiles &
    mv ${HERE}/nc/*_P{000..023}.nc ${archive}/nc/ || exit 1
    rm -r ${HERE}/nc &

    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
