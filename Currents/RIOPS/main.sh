#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_riops/netcdf/forecast/polar_stereographic/3d/00/"

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/Currents/RIOPS
export archive=/media/taimaz/14TB/Currents/RIOPS


curl ${ftpLink}048/ > ${HERE}/files
export lastAvailDate=`grep MSC_RIOPS_VOMECRTY_DBS-all_PS5km ${HERE}/files | tail -1 | sed 's/.*href=\"\(.*\)T00Z.*\".*/\1/'`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/files


############################################################################
##  FUNCTIONS

function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    dlLinkU="${ftpLink}${hr}/${lastAvailDate}T00Z_MSC_RIOPS_VOZOCRTX_DBS-all_PS5km_P${hr}.nc"
    axel -c -a -n 50 -o ${HERE}/nc/ ${dlLinkU}
    
    dlLinkV="${ftpLink}${hr}/${lastAvailDate}T00Z_MSC_RIOPS_VOMECRTY_DBS-all_PS5km_P${hr}.nc"
    axel -c -a -n 50 -o ${HERE}/nc/ ${dlLinkV}
}
export -f dl


function regrid {
    hr=$1
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${lastAvailDate}T00Z_MSC_RIOPS_VOZOCRTX_DBS-all_PS5km_P${hr}.nc CMC_RIOPS_ux_${lastAvailDate}_${hr}.nc
    
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${lastAvailDate}T00Z_MSC_RIOPS_VOMECRTY_DBS-all_PS5km_P${hr}.nc CMC_RIOPS_vy_${lastAvailDate}_${hr}.nc
}
export -f regrid


function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr}
}
export -f py


##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    mkdir ${HERE}/nc/
    mkdir ${HERE}/png/
    mkdir ${HERE}/jpg/
	
    cd ${HERE}/nc/

    echo -e "\tDownloading ..." ; parallel -j 4 "dl {}" ::: {000..048..3}
    echo -e "\tRegridding ..." ; parallel -j 6 "regrid {}" ::: {000..048..3}
    echo -e "\tProcessing ..." ; parallel -j 6 "py {}" ::: {000..048..3}  ## depth averaging and image saving

    rm ${HERE}/nc/*VOMECRTY* ${HERE}/nc/*VOZOCRTX*
    
    
    ##################################################
    ##  Convert png to jpg  (png's are big)
    echo -e "\tpng to jpg ..."
    cd ${HERE}/png/
    ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
    rm -r ${HERE}/png/
    
    cd ${HERE}/jpg/
    for f in RIOPS_Currents_*.jpg; do
        dir=`echo $f | cut -d_ -f1-4`
        mkdir ${dir}
        mv ${dir}*.jpg ${dir}
    done

    
    ##################################################
    ##  Copy jpg's to server
    rsync -aur ${HERE}/jpg taimaz@159.203.6.104:/mnt/data/models/Currents/RIOPS/ &
    
    
    ##################################################
    ##  Backup jpg's
    rsync -aur ${HERE}/jpg ${archive}
    rm -r ${HERE}/jpg/ &


    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    rm ${archive}/gntForecast/*
    cd ${HERE}/nc/
    cdo -O ensmean ${HERE}/nc/RIOPS_Currents_avgDepth_${lastAvailDate}_*.nc ${archive}/gntForecast/RIOPS_Currents_avgDepth_avgTime_forecast.nc

    ##  Copy to data-process
    ssh 192.168.2.11 << EOF
rm /home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/RIOPS/forecast/*
EOF
    mv ${HERE}/nc/RIOPS_Currents_avgDepth_${lastAvailDate}_*.nc ${archive}/gntForecast/
    rsync -au ${archive}/gntForecast/* 192.168.2.11:/home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/RIOPS/forecast/ &


    #####################################################
    ##  Path Planning hindcast file:  7 days before today (7*24 files)
    rm ${archive}/gntHindcast/*
    cd ${archive}/hindcast/
    cdo -O ensmean `ls RIOPS_Currents_avgDepth_2*.nc | tail -168` ${archive}/gntHindcast/RIOPS_Currents_avgDepth_avgTime_7d.nc
    cdo -O ensstd `ls RIOPS_Currents_avgDepth_2*.nc | tail -168` ${archive}/gntHindcast//RIOPS_Currents_avgDepth_stdTime_7d.nc
    ncrename -O -v u,u_mean -v v,v_mean ${archive}/gntHindcast/RIOPS_Currents_avgDepth_avgTime_7d.nc
    ncrename -O -v u,u_std -v v,v_std ${archive}/gntHindcast/RIOPS_Currents_avgDepth_stdTime_7d.nc
    cdo -O merge ${archive}/gntHindcast/RIOPS_Currents_avgDepth_avgTime_7d.nc ${archive}/gntHindcast/RIOPS_Currents_avgDepth_stdTime_7d.nc ${archive}/gntHindcast/RIOPS_Currents_avgDepth_avgstdTime_7d.nc
    rm ${archive}/gntHindcast/RIOPS_Currents_avgDepth_stdTime_7d.nc ${archive}/gntHindcast/RIOPS_Currents_avgDepth_avgTime_7d.nc
    cp ${archive}/gntForecast/RIOPS_Currents_avgDepth_2*.nc ${archive}/hindcast/


    #####################################################
    ##  Copy to server
    ssh 192.168.2.11 <<EOF
rm /home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/RIOPS/hindcast/*
EOF
    rsync -au ${archive}/gntHindcast/* 192.168.2.11:/home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/RIOPS/hindcast/

    
    #####################################################
    ##  Archive original files
    cd ${HERE}/nc/
    ls CMC_RIOPS_*{000..021..3}.nc | parallel 'tar czf {}.tar.gz {}'
    mv ${HERE}/nc/*.tar.gz ${archive}/nc/
    rm -r ${HERE}/nc/ &

    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
