#!/bin/bash
ftpLink="https://dd.meteo.gc.ca/model_riops/netcdf/forecast/polar_stereographic/3d/00/"


############################################################################

HERE=${HOME}/Projects/mapBoxData/riops
log=${HOME}/Projects/mapBoxData/log/fields.log

curl ${ftpLink}033/ > ${HERE}/files
lastAvailDate=`grep CMC_riops_vozocrtx files | tail -1 | sed 's/.*CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_\(.*\)00_P033.nc.*/\1/'`
lastDlDate=`cat lastDlDate.txt`

mkdir ${HERE}/nc/hindcast 2>/dev/null


if [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    for time in {012..033..3}; do
	dlLinkU=${ftpLink}${time}/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P${time}.nc
	axel -c -a -n 50 -o ${HERE}/nc/hindcast/ ${dlLinkU}
	# wget -O ${HERE}/nc/hindcast ${dlLinkU}

        dlLinkV="${ftpLink}${time}/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P${time}.nc"
        axel -c -a -n 50 -o ${HERE}/nc/hindcast/ ${dlLinkV}
	# wget -O ${HERE}/nc/hindcast ${dlLinkV}
    done


    ############################################################################
    ##  Forecast:  Last downloaded day

    ##  Average time
    cdo -O ensmean ${HERE}/nc/hindcast/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P*.nc ${HERE}/nc/ux_allDepth_avgTime_forecast.nc &
    pid1=$!
    cdo -O ensmean ${HERE}/nc/hindcast/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_${lastAvailDate}00_P*.nc ${HERE}/nc/vy_allDepth_avgTime_forecast.nc &
    pid2=$!

    wait ${pid1}
    wait ${pid2}
    
    ##  Merge ux and vy into one file
    cdo -O merge ${HERE}/nc/ux_allDepth_avgTime_forecast.nc ${HERE}/nc/vy_allDepth_avgTime_forecast.nc ${HERE}/nc/uxvy_allDepth_avgTime_forecast.nc || exit 1
    rm ${HERE}/nc/ux_allDepth_avgTime_forecast.nc ${HERE}/nc/vy_allDepth_avgTime_forecast.nc
    

    ##  Average depth, and
    ##  Convert:  ux -> u ; vy -> v
    cd ${HERE}/nc
    python3 ${HERE}/scripts/cnv.py uxvy_allDepth_avgTime_forecast.nc || exit 1
    rm ${HERE}/nc/uxvy_allDepth_avgTime_forecast.nc
    mv ${HERE}/nc/uxvy_avgDepth_avgTime_forecast.nc ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc


    ##  Regrid for path planning
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc  ##  ...
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/uv_avgDepth_avgTime_forecast.nc ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid_tmp.nc
    ferret <<EOF
use uv_avgDepth_avgTime_forecast_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="uv_avgDepth_avgTime_forecast_regrid.nc" longitude,latitude,u,v
exit
EOF
    ncrename -O -v LONGITUDE,longitude -v LATITUDE,latitude -v U,u -v V,v ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid.nc || exit 1
    rm ${HERE}/nc/uv_avgDepth_avgTime_forecast_regrid_tmp.nc
    

    ##  Convert nc to geojson for point data
    ##  Sampling every 2 point
    cd ${HERE}
    python3 ${HERE}/scripts/nc2geojson.py || exit 1

    
    ##  Upload and publish on mapbox
    cd ${HERE}/gj
    bash ${HERE}/scripts/addTileset.sh
    
    
    ############################################################################
    ##  Hindcast:  Last 7 days
    cd ${HERE}

    ##  Average time
    cdo -O ensmean `ls ${HERE}/nc/hindcast/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_*00_P*.nc | tail -56` ${HERE}/nc/ux_allDepth_avgTime_7d.nc &
    pid1=$!
    cdo -O ensmean `ls ${HERE}/nc/hindcast/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_*00_P*.nc | tail -56` ${HERE}/nc/vy_allDepth_avgTime_7d.nc &
    pid2=$!
    cdo -O ensstd `ls ${HERE}/nc/hindcast/CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_*00_P*.nc | tail -56` ${HERE}/nc/ux_allDepth_stdTime_7d.nc &
    pid3=$!
    cdo -O ensstd `ls ${HERE}/nc/hindcast/CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_*00_P*.nc | tail -56` ${HERE}/nc/vy_allDepth_stdTime_7d.nc &
    pid4=$!

    wait ${pid1}
    wait ${pid2}
    wait ${pid3}
    wait ${pid4}
    
    ##  Merge ux and vy into one file.  Separately for mean and std.
    cdo -O merge ${HERE}/nc/ux_allDepth_avgTime_7d.nc ${HERE}/nc/vy_allDepth_avgTime_7d.nc ${HERE}/nc/uxvy_allDepth_avgTime_7d.nc || exit 1
    cdo -O merge ${HERE}/nc/ux_allDepth_stdTime_7d.nc ${HERE}/nc/vy_allDepth_stdTime_7d.nc ${HERE}/nc/uxvy_allDepth_stdTime_7d.nc || exit 1
    rm ${HERE}/nc/ux_allDepth_avgTime_7d.nc ${HERE}/nc/vy_allDepth_avgTime_7d.nc ${HERE}/nc/ux_allDepth_stdTime_7d.nc ${HERE}/nc/vy_allDepth_stdTime_7d.nc
    

    ##  Average depth, then
    ##  Convert:  ux -> u ; vy -> v
    cd ${HERE}/nc
    python3 ${HERE}/scripts/cnv.py ${HERE}/nc/uxvy_allDepth_avgTime_7d.nc || exit 1
    python3 ${HERE}/scripts/cnv.py ${HERE}/nc/uxvy_allDepth_stdTime_7d.nc || exit 1
    rm ${HERE}/nc/uxvy_allDepth_avgTime_7d.nc ${HERE}/nc/uxvy_allDepth_stdTime_7d.nc
    mv ${HERE}/nc/uxvy_avgDepth_avgTime_7d.nc ${HERE}/nc/uv_avgDepth_avgTime_7d.nc
    mv ${HERE}/nc/uxvy_avgDepth_stdTime_7d.nc ${HERE}/nc/uv_avgDepth_stdTime_7d.nc
    

    ##  Regrid for path planning
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_7d.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_avgTime_7d.nc  ##  ...
    ncatted -O -a coordinates,u,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_stdTime_7d.nc  ##  Needed for remapbil
    ncatted -O -a coordinates,v,c,c,"latitude longitude" ${HERE}/nc/uv_avgDepth_stdTime_7d.nc  ##  ...
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/uv_avgDepth_avgTime_7d.nc ${HERE}/nc/uv_avgDepth_avgTime_7d_regrid_tmp.nc
    cdo -O remapbil,${HERE}/nc/.grid.txt ${HERE}/nc/uv_avgDepth_stdTime_7d.nc ${HERE}/nc/uv_avgDepth_stdTime_7d_regrid_tmp.nc
    rm ${HERE}/nc/uv_avgDepth_avgTime_7d.nc ${HERE}/nc/uv_avgDepth_stdTime_7d.nc
    ferret <<EOF
use uv_avgDepth_avgTime_7d_regrid_tmp.nc
let longitude = x[gx=lon]
let latitude = y[gy=lat]
save/clob/file="uv_avgDepth_avgTime_7d_regrid.nc" longitude,latitude,u,v
exit
EOF
    ferret <<EOF
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

    
    ############################################################################
    ##  Copy to data-process
    ##   Done by data-process itself
    
    
    echo ${lastAvailDate} > ${HERE}/lastDlDate.txt
    echo -e "##  RIOPS:\tUpdated @ `date`" >> ${log}

    echo "RIOPS,`date +%FT%T`" >> ${HERE}/../lastUpdated.dat
    scp ${HERE}/../lastUpdated.dat taimaz@mungliders.com:/home/taimaz/node/public/
else
    echo -e "##  RIOPS:\tNo new file available yet @ `date`" >> ${log}
fi

rm ${HERE}/files
