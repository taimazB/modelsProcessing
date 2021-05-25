#!/bin/bash
export ftpLink="https://dd.weather.gc.ca/model_gem_regional/coupled/gulf_st-lawrence/grib2/00/"

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/Currents/CMC
export archive=/media/taimaz/14TB/Currents/CMC

curl ${ftpLink}048/ > ${HERE}/files
export lastAvailDate=`grep CMC_coupled-rdps-stlawrence-ocean files | tail -1 | sed 's/.*href=\"CMC_coupled-rdps-stlawrence-ocean_latlon0\.02x0\.03_\(.*\)00_P048.*\".*/\1/'`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/files


############################################################################
##  FUNCTIONS

function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    dlLink="${ftpLink}${hr}/CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}00_P${hr}.grib2"
    axel -c -a -n 50 -o ${HERE}/nc/forecast/ ${dlLink}
}
export -f dl


function grib2nc {
    hr=$1
    cdo -f nc copy CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}00_P${hr}.grib2 CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}00_P${hr}.nc
    rm CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}00_P${hr}.grib2
}
export -f grib2nc


function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr}
}
export -f py


##  FUNCTIONS
############################################################################


if [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    mkdir -p ${HERE}/nc/forecast/
    mkdir ${HERE}/png/
    mkdir ${HERE}/jpg/

    cd ${HERE}/nc/forecast/

    echo -e "\tDownloading ..." ; parallel -j 4 "dl {}" ::: {001..048..1}
    echo -e "\tRegridding ..." ; parallel -j 4 "grib2nc {}" ::: {001..048..1}
    echo -e "\tProcessing ..." ; parallel -j 16 "py {}" ::: {001..048..1}  ## depth averaging and image saving


    ##################################################
    ##  Convert png to jpg  (png's are big)
    echo -e "\tpng to jpg ..."
    cd ${HERE}/png/
    ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
    rm -r ${HERE}/png/

    cd ${HERE}/jpg/
    for f in CMC_Currents_*.jpg; do
        dir=`basename $f .jpg`
        mkdir ${dir}
        mv ${dir}*.jpg ${dir}
    done

    
    ##################################################
    ##  Copy jpg's to server
    rsync -aur ${HERE}/jpg taimaz@159.203.6.104:/mnt/data/models/Currents/CMC/


    ##################################################
    ##  Backup jpg's
    rsync -aur ${HERE}/jpg ${archive}/
    rm -r ${HERE}/jpg/
    
    
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    # echo -e "\tFinalizing forecast files ..."
    # cd ${HERE}/nc/forecast/
    # cdo -O ensmean ${HERE}/nc/forecast/CMC_Currents_surface_${lastAvailDate}_{01..23..1}.nc ${HERE}/nc/CMC_Currents_surface_avgTime_forecast.nc


    #####################################################
    ##  Path Planning hindcast file:  7 days before today (7*24 files)
    # echo -e "\tFinalizing hindcast files ..."
    # cd ${archive}/nc/
    # cdo -O ensmean `ls CMC_Currents_surface_2*.nc | tail -168` ${HERE}/nc/CMC_Currents_surface_avgTime_7d.nc
    # cdo -O ensstd `ls CMC_Currents_surface_2*.nc | tail -168` ${HERE}/nc/CMC_Currents_surface_stdTime_7d.nc
    
    # ncrename -O -v u,u_mean -v v,v_mean ${HERE}/nc/CMC_Currents_surface_avgTime_7d.nc
    # ncrename -O -v u,u_std -v v,v_std ${HERE}/nc/CMC_Currents_surface_stdTime_7d.nc
    # cdo -O merge ${HERE}/nc/CMC_Currents_surface_avgTime_7d.nc ${HERE}/nc/CMC_Currents_surface_stdTime_7d.nc ${HERE}/nc/CMC_Currents_surface_avgstdTime_7d.nc
    # rm ${HERE}/nc/CMC_Currents_surface_stdTime_7d.nc ${HERE}/nc/CMC_Currents_surface_avgTime_7d.nc


    ##################################################
    ##  Backup nc files
    mv ${HERE}/nc/forecast/CMC_Currents_surface_2*.nc ${archive}/nc/ &


    #####################################################
    ##  Backup original files
    cd ${HERE}/nc/forecast/
    ls CMC_coupled-rdps*{001..023}.nc | parallel 'tar czf {}.tar.gz {}'
    mv ${HERE}/nc/forecast/*.tar.gz /media/taimaz/14TB/CMC_GOSL/
    cd ${HERE}
    rm -r ${HERE}/nc/ &

    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
