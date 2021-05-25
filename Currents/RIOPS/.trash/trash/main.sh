#!/bin/bash
ftpLink="https://dd.meteo.gc.ca/model_riops/netcdf/forecast/polar_stereographic/3d/00/"


############################################################################

HERE=${HOME}/Projects/mapBoxData/riops
# log=${HOME}/Projects/mapBoxData/log/fields.log

curl ${ftpLink}048/ > ${HERE}/files
lastAvailDate=`grep CMC_riops_vozocrtx ${HERE}/files | tail -1 | sed 's/.*CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_\(.*\)00_P048.nc.*/\1/'`
lastDlDate=`sed -n '2p' ${HERE}/availDates.txt | sed 's/_00//'`


if [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    ##  Download + avgDepth + convert ux,vy + merge u,v
    cd ${HERE}/nc/forecast/
    rm ${HERE}/nc/forecast/*
    for hr in {000..021..3}; do
    	echo "##  ${lastAvailDate}_${hr}"
    	dlLinkU="${ftpLink}${hr}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P${hr}.nc"
    	axel -c -a -n 50 -o ${HERE}/nc/forecast/ ${dlLinkU}

        dlLinkV="${ftpLink}${hr}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P${hr}.nc"
        axel -c -a -n 50 -o ${HERE}/nc/forecast/ ${dlLinkV}

    	##  Average depth;  Convert ux to u & vy to v;  Save u & v in one file
    	python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr} || exit 1
    done


    echo Date > ${HERE}/availDates.txt
    for d in `ls uv_avgDepth_* | sed 's/uv_avgDepth_// ; s/\.nc//'`; do
	date=`echo $d | sed 's/_.*//'`
	hr=`echo $d | sed 's/.*_0*//'`
	if [[ $hr -ge 24 ]]; then
	    hr=$((hr-24))
	    date=`date -d "${date} +1 day" +%Y-%m-%d`
	    echo ${date}_`printf %02d ${hr}`
	else
	    echo ${date}_`printf %02d ${hr}`
	fi
    done >> ${HERE}/availDates.txt


    #########################
    ##  Convert nc to geojson
    ##  next 48 hours (17 files)
    ##  Sampling every 2 point
    cd ${HERE}/nc/forecast/
    parallel --link  "python3 ${HERE}/scripts/nc2geojson.py {}" ::: `ls uv_avgDepth_*.nc` ::: {1..16}
    mv ${HERE}/nc/forecast/*.geojson ${HERE}/gj/


    ##################################################
    ##  Path Planning forecast file:  average 24 hours
    cd ${HERE}/nc/forecast/
    cdo -O ensmean ${HERE}/nc/forecast/uv_avgDepth_*_{00..21..3}.nc ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc

    ##  Path Planning forecast file:  regrid
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc  ##  ...
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid_tmp.nc

    cd ${HERE}/nc
    ferret_c <<EOF
use uv_avgDepth_avgTime_forecast_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="uv_avgDepth_avgTime_forecast_regrid.nc" longitude,latitude,u,v
exit
EOF
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u -v V,v ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid.nc || exit 1
    rm ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid_tmp.nc
    

    #####################################################
    ##  Path Planning hindcast file:  7 days before today
    cd ${HERE}/nc/hindcast/
    cdo -O ensmean `ls ${HERE}/nc/hindcast/uv_avgDepth_*.nc | tail -56` ${HERE}/nc/uv_avgDepth_avgTime_7d.nc
    cdo -O ensstd `ls ${HERE}/nc/hindcast/uv_avgDepth_*.nc | tail -56` ${HERE}/nc/uv_avgDepth_stdTime_7d.nc

    ##  Path Planning hindcast file:  regrid
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_7d.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_7d.nc  ##  ...
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_stdTime_7d.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_stdTime_7d.nc  ##  ...
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/uv_avgDepth_avgTime_7d.nc ${HERE}/nc/uv_avgDepth_avgTime_7d_regrid_tmp.nc
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/uv_avgDepth_stdTime_7d.nc ${HERE}/nc/uv_avgDepth_stdTime_7d_regrid_tmp.nc
    rm ${HERE}/nc/uv_avgDepth_avgTime_7d.nc ${HERE}/nc/uv_avgDepth_stdTime_7d.nc

    cd ${HERE}/nc
    ferret_c <<EOF
use uv_avgDepth_avgTime_7d_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="uv_avgDepth_avgTime_7d_regrid.nc" longitude,latitude,u,v
exit
EOF
    ferret_c <<EOF
use uv_avgDepth_stdTime_7d_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="uv_avgDepth_stdTime_7d_regrid.nc" longitude,latitude,u,v
exit
EOF
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u_mean -v V,v_mean ${HERE}/nc/uv_avgDepth_avgTime_7d_regrid.nc
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u_std -v V,v_std ${HERE}/nc/uv_avgDepth_stdTime_7d_regrid.nc
    rm ${HERE}/nc/uv_avgDepth_avgTime_7d_regrid_tmp.nc ${HERE}/nc/uv_avgDepth_stdTime_7d_regrid_tmp.nc

    cdo -O merge ${HERE}/nc/uv_avgDepth_avgTime_7d_regrid.nc ${HERE}/nc/uv_avgDepth_stdTime_7d_regrid.nc ${HERE}/nc/uv_avgDepth_avgstdTime_7d_regrid.nc
    rm ${HERE}/nc/uv_avgDepth_avgTime_7d_regrid.nc ${HERE}/nc/uv_avgDepth_stdTime_7d_regrid.nc

    rm ${HERE}/nc/ferret.jnl*
    

    ##################################################################
    ##  Move new forecast to hindcast for future hindcast calculations
    mv `ls ${HERE}/nc/forecast/uv_avgDepth_* | head -8` ${HERE}/nc/hindcast/


    ##  Remove unwanted files
    rm ${HERE}/nc/forecast/*
    

    ##########################
    ##  Copy to data-process
    rsync -auv ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid.nc taimaz@159.203.6.104:/home/taimaz/gnt/Datasets/riops/latest
    rsync -auv ${HERE}/nc/uv_avgDepth_avgstdTime_7d_regrid.nc taimaz@159.203.6.104:/home/taimaz/gnt/Datasets/riops/hindcast
    

    ################################
    ##  Upload and publish on mapbox
    cd ${HERE}/gj
    for I in {01..16}; do
	bash ${HERE}/scripts/addTileset.sh $I
	while [[ $? -ne 0 ]]; do
	    echo "##  Re-adding $I ..."
	    sleep 5
	    bash ${HERE}/scripts/addTileset.sh $I
	done
    done

    
    ########
    ##  logs
    scp ${HERE}/availDates.txt taimaz@159.203.6.104:web/public/layers/riops_availDates.txt
    scp ${HERE}/availDates.txt ${HOME}/Projects/mungliders/web/public/layers/riops_availDates.txt
fi

rm ${HERE}/files
