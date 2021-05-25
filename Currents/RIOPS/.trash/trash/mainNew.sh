#!/bin/bash
ftpLink="https://dd.meteo.gc.ca/model_riops/netcdf/forecast/polar_stereographic/3d/00/"


############################################################################

HERE=${HOME}/Projects/mapBoxData/riops
# log=${HOME}/Projects/mapBoxData/log/fields.log

curl ${ftpLink}048/ > ${HERE}/files
lastAvailDate=`grep CMC_riops_vozocrtx ${HERE}/files | tail -1 | sed 's/.*CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_\(.*\)00_P048.nc.*/\1/'`
lastDlDate=`sed -n '2p' ${HERE}/availDates.txt | sed 's/_00//'`

mkdir -p ${HERE}/nc/ ${HERE}/nc/hindcast/ ${HERE}/nc/forecast/ ${HERE}/nc/org/ ${HERE}/csv/

if [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    ##  Download + avgDepth + convert ux,vy + merge u,v
    for hr in {000..045..3}; do
    	echo "##  ${lastAvailDate}_${hr}"
	
    	dlLinkU="${ftpLink}${hr}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P${hr}.nc"
    	axel -c -a -n 50 -o ${HERE}/nc/org/ ${dlLinkU}

        dlLinkV="${ftpLink}${hr}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P${hr}.nc"
        axel -c -a -n 50 -o ${HERE}/nc/org/ ${dlLinkV}
	
    	##  Average depth;  Convert ux to u & vy to v;  Save u & v in one file
    	python3 ${HERE}/scripts/cnvNew.py ${lastAvailDate} ${hr}
    done

    
    cd ${HERE}/nc/forecast/
    for d in `ls RIOPS_UV_avgDepth_* | sed 's/RIOPS_UV_avgDepth_// ; s/\.nc//'`; do
	date=`echo $d | sed 's/_.*//'`
	hr=`echo $d | sed 's/.*_//'`
	echo ${date}_`printf %02d ${hr}`
    done > ${HERE}/availDates.txt


    ##################################################
    ##  Path Planning forecast file:  average 24 hours
    cd ${HERE}/nc/forecast/
    cdo -O ensmean ${HERE}/nc/forecast/RIOPS_UV_avgDepth_${lastAvailDate}_{00..21..3}.nc ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast.nc

    ##  Path Planning forecast file:  regrid
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast.nc  ##  ...
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast.nc ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast_regrid_tmp.nc

    cd ${HERE}/nc
    ferret_c <<EOF
use RIOPS_UV_avgDepth_avgTime_forecast_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="RIOPS_UV_avgDepth_avgTime_forecast_regrid.nc" longitude,latitude,u,v
exit
EOF
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u -v V,v ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast_regrid.nc
    rm ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast.nc ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast_regrid_tmp.nc
    

    #####################################################
    ##  Path Planning hindcast file:  7 days before today
    cd ${HERE}/nc/hindcast/
    cdo -O ensmean `ls ${HERE}/nc/hindcast/RIOPS_UV_avgDepth_*.nc | tail -56` ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d.nc
    cdo -O ensstd `ls ${HERE}/nc/hindcast/RIOPS_UV_avgDepth_*.nc | tail -56` ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d.nc

    ##  Path Planning hindcast file:  regrid
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d.nc  ##  ...
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d.nc  ##  ...
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d.nc ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d_regrid_tmp.nc
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d.nc ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d_regrid_tmp.nc
    rm ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d.nc ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d.nc

    cd ${HERE}/nc
    ferret_c <<EOF
use RIOPS_UV_avgDepth_avgTime_7d_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="RIOPS_UV_avgDepth_avgTime_7d_regrid.nc" longitude,latitude,u,v
exit
EOF
    ferret_c <<EOF
use RIOPS_UV_avgDepth_stdTime_7d_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="RIOPS_UV_avgDepth_stdTime_7d_regrid.nc" longitude,latitude,u,v
exit
EOF
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u_mean -v V,v_mean ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d_regrid.nc
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u_std -v V,v_std ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d_regrid.nc
    rm ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d_regrid_tmp.nc ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d_regrid_tmp.nc

    cdo -O merge ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d_regrid.nc ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d_regrid.nc ${HERE}/nc/RIOPS_UV_avgDepth_avgstdTime_7d_regrid.nc
    rm ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_7d_regrid.nc ${HERE}/nc/RIOPS_UV_avgDepth_stdTime_7d_regrid.nc

    rm ${HERE}/nc/ferret.jnl*
    

    ##################################################################
    ##  Move new forecast to hindcast for future hindcast calculations
    mv `ls ${HERE}/nc/forecast/RIOPS_UV_avgDepth_${lastAvailDate}` ${HERE}/nc/hindcast/


    ##  Remove unwanted files
    rm ${HERE}/nc/forecast/*
    

    ##########################
    ##  Copy to data-process
    rsync -auv ${HERE}/nc/RIOPS_UV_avgDepth_avgTime_forecast_regrid.nc taimaz@159.203.6.104:/home/taimaz/gnt/Datasets/riops/latest/uv_avgDepth_avgTime_forecast_regrid.nc
    rsync -auv ${HERE}/nc/RIOPS_UV_avgDepth_avgstdTime_7d_regrid.nc taimaz@159.203.6.104:/home/taimaz/gnt/Datasets/riops/hindcast/uv_avgDepth_avgstdTime_7d_regrid.nc
    

    ########
    ##  logs
    scp ${HERE}/availDates.txt taimaz@159.203.6.104:web/public/layers/riops_availDates.txt
    scp ${HERE}/availDates.txt ${HOME}/Projects/mungliders/web/public/layers/riops_availDates.txt
fi

rm ${HERE}/files
