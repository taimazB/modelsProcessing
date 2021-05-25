#!/bin/bash
ftpLink='https://ncss.hycom.org/thredds/ncss/GLBy0.08/expt_93.0/FMRC/runs/'

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/Currents/HYCOM
export archive=/media/taimaz/14TB/Currents/HYCOM

lastAvailDate=`curl https://tds.hycom.org/thredds/catalog/GLBy0.08/expt_93.0/FMRC/runs/catalog.html | grep GLBy | grep '^<a' | head -1 | sed 's/.*GLBy0\.08_930_FMRC_RUN_\(.*\)T12.*/\1/' | sed 's/-//g'`
lastDlDate=`cat ${HERE}/.lastAvailDate`


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    mkdir ${HERE}/nc/
    mkdir ${HERE}/png/
    mkdir -p ${HERE}/jpg/highRes ${HERE}/jpg/lowRes
    

    ##  Download (next 48 hr)
    redo=1
    while [[ redo -eq 1 ]]; do
    	cd ${HERE}/nc
    	date=${lastAvailDate}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=-180&east=0&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {12..21..3}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=0&east=180&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {12..21..3}

    	date=`date -d "${date} +1 day" +%Y%m%d`
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=-180&east=0&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=0&east=180&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
    
    	date=`date -d "${date} +1 day" +%Y%m%d`
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=-180&east=0&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=0&east=180&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}


    	##  Check for bad downloads
    	redo=0
    	for f in *.nc; do
    	    ncdump -h $f > /dev/null
    	    if [[ $? -ne 0 ]]; then
    		redo=1
    		rm $f
    	    fi
    	done
    done
exit
    
    #########################
    ##  Average depth
    cd ${HERE}/nc/
    ls *_west.nc | sed 's/HYCOM_Currents_\(.*\)_west\.nc/\1/' | parallel -j 2 'python3 ${HERE}/scripts/cnv.py {}'

    
    ##################################################
    ##  Convert png to jpg  (png's are too big)
    cd ${HERE}/png/
    ls *.png | parallel 'convert {} ../jpg/highRes/`basename {} .png`.jpg'
    ls *.png | parallel 'convert -resize 30% {} ../jpg/lowRes/`basename {} .png`.jpg'
    rm -r ${HERE}/png/
    
    cd ${HERE}/jpg/highRes/
    for f in HYCOM_Currents_*.jpg; do
	dir=`echo $f | cut -d_ -f1-4`
	mkdir ${dir} 2>/dev/null
	mv ${dir}*.jpg ${dir} 2>/dev/null
    done

    cd ${HERE}/jpg/lowRes/
    for f in HYCOM_Currents_*.jpg; do
	dir=`echo $f | cut -d_ -f1-4`
	mkdir ${dir} 2>/dev/null
	mv ${dir}*.jpg ${dir} 2>/dev/null
    done
    
    
    ##################################################
    ##  Copy jpg's to server
    rsync -aur ${HERE}/jpg taimaz@159.203.6.104:/mnt/data/models/Currents/HYCOM/


    ##################################################
    ##  Backup jpg's
    cd ${HERE}
    mv ${HERE}/jpg/highRes/* ${archive}/jpg/highRes
    mv ${HERE}/jpg/lowRes/* ${archive}/jpg/lowRes
    rm -r ${HERE}/jpg/
    
    
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    rm ${archive}/gntForecast/*
    date=`date -d "${lastAvailDate} +1 day" +%Y%m%d`
    cd ${HERE}/nc/
    cdo -O ensmean ${HERE}/nc/HYCOM_Currents_avgDepth_${date}*.nc ${archive}/gntForecast/HYCOM_Currents_avgDepth_avgTime_forecast.nc


    #####################################################
    ##  Copy to server
    ssh 192.168.2.11 <<EOF
rm /home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/HYCOM/forecast/*
EOF
    mv ${HERE}/nc/HYCOM_Currents_avgDepth_${date}*.nc ${archive}/gntForecast/
    rsync -auz ${archive}/gntForecast/* 192.168.2.11:/home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/HYCOM/forecast/ &
    

    #####################################################
    ##  Path Planning hindcast file:  7 days before today
    rm ${archive}/gntHindcast/*
    cd ${archive}/hindcast/
    cdo -O ensmean `ls HYCOM_Currents_avgDepth_*.nc | tail -56` ${archive}/gntHindcast/HYCOM_Currents_avgDepth_avgTime_7d.nc
    cdo -O ensstd `ls HYCOM_Currents_avgDepth_*.nc | tail -56` ${archive}/gntHindcast/HYCOM_Currents_avgDepth_stdTime_7d.nc
    ncrename -O -v u,u_mean -v v,v_mean ${archive}/gntHindcast/HYCOM_Currents_avgDepth_avgTime_7d.nc
    ncrename -O -v u,u_std -v v,v_std ${archive}/gntHindcast/HYCOM_Currents_avgDepth_stdTime_7d.nc

    cdo -O merge ${archive}/gntHindcast/HYCOM_Currents_avgDepth_avgTime_7d.nc ${archive}/gntHindcast/HYCOM_Currents_avgDepth_stdTime_7d.nc ${archive}/gntHindcast/HYCOM_Currents_avgDepth_avgstdTime_7d.nc
    rm ${archive}/gntHindcast/HYCOM_Currents_avgDepth_avgTime_7d.nc ${archive}/gntHindcast/HYCOM_Currents_avgDepth_stdTime_7d.nc
    cp ${archive}/gntForecast/HYCOM_Currents_avgDepth_2*.nc ${archive}/hindcast/


    #####################################################
    ##  Copy to server
    ssh 192.168.2.11 <<EOF
rm /home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/HYCOM/hindcast/*
EOF
    rsync -au ${archive}/gntHindcast/HYCOM_Currents_avgDepth_avgstdTime_7d.nc 192.168.2.11:/home/taimaz/Projects/oceanGNS/web/api/public/gnt/Datasets/HYCOM/hindcast/


    #####################################################
    ##  Archeive original files
    cd ${HERE}
    mv ${HERE}/nc/HYCOM_Currents_*_east.nc ${archive}/nc/
    mv ${HERE}/nc/HYCOM_Currents_*_west.nc ${archive}/nc/
    rm -r ${HERE}/nc &
    

    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
