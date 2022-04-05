#!/bin/bash
ftpLink='https://ncss.hycom.org/thredds/ncss/GLBy0.08/expt_93.0/FMRC/runs/'
IP='143.110.215.10'

############################################################################

export HERE=${HOME}/Projects/data/Currents/HYCOM
export archive=taimaz@taimazhome.ddns.net:/media/taimaz/14TB/Currents/HYCOM
export pathPlanning=taimaz@taimazhome.ddns.net:Projects/OceanGNS/pathPlanning/gnt/Datasets/HYCOM/


lastAvailDate=`curl https://tds.hycom.org/thredds/catalog/GLBy0.08/expt_93.0/FMRC/runs/catalog.html | grep GLBy | grep '^<a' | head -1 | sed 's/.*GLBy0\.08_930_FMRC_RUN_\(.*\)T12.*/\1/' | sed 's/-//g'`
lastDlDate=`cat ${HERE}/.lastAvailDate`


function backJobs(){
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    date=`date -d "${lastAvailDate} +1 day" +%Y%m%d`
    cd ${HERE}/nc/
    cdo -O ensmean ${HERE}/nc/HYCOM_Currents_avgDepth_${date}*.nc ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime.nc


    #####################################################
    ##  Path Planning hindcast file:  7 days before today
    # cd ${archive}/hindcast/
    # cdo -O ensmean `ls HYCOM_Currents_avgDepth_*.nc | tail -56` ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc
    # cdo -O ensstd `ls HYCOM_Currents_avgDepth_*.nc | tail -56` ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc
    # ncrename -O -v u,u_mean -v v,v_mean ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc
    # ncrename -O -v u,u_std -v v,v_std ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc

    # cdo -O merge ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc ${HERE}/nc/HYCOM_Currents_avgDepth_avgstdTime_7d.nc
    # rm ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc
    # cp ${pathPlanning}/forecast/HYCOM_Currents_avgDepth_2*.nc ${archive}/hindcast/
    #####################################################
    ##  Copy to server
    # mv ${HERE}/nc/HYCOM_Currents_avgDepth_avgstdTime_7d.nc ${pathPlanning}/hindcast/


    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy nc files to path planning server
	rsync -auq --timeout=10000 --delete -e 'ssh -p 4412' ${HERE}/nc/HYCOM_Currents_avgDepth_*.nc ${pathPlanning}/forecast/
	resync=`echo "${resync} + $?" | bc`
	##  Copy processed nc files
	rsync -auq --timeout=10000 -e 'ssh -p 4412' ${HERE}/nc/HYCOM_Currents_avgDepth_2*.nc ${archive}/hindcast/
	resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles ${archive}/
	resync=`echo "${resync} + $?" | bc`
	##  Copy original nc files to archive
	rsync -auq --timeout=10000 -e 'ssh -p 4412' ${HERE}/nc/HYCOM_Currents_*_east.nc ${archive}/nc/
	resync=`echo "${resync} + $?" | bc`
	rsync -auq --timeout=10000 -e 'ssh -p 4412' ${HERE}/nc/HYCOM_Currents_*_west.nc ${archive}/nc/
	resync=`echo "${resync} + $?" | bc`
    done
}


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    rm -r ${HERE}/nc/
    mkdir ${HERE}/nc/

    ##  Download (next 48 hr)
    redo=1
    c=0
    while [[ redo -eq 1 ]] && [[ c -le 10 ]]; do
    	cd ${HERE}/nc
    	date=${lastAvailDate}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=-180&east=0&south=-80&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {12..21..3}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=0&east=180&south=-80&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {12..21..3}

    	date=`date -d "${date} +1 day" +%Y%m%d`
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=-180&east=0&south=-80&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=0&east=180&south=-80&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}

    	date=`date -d "${date} +1 day" +%Y%m%d`
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=-180&east=0&south=-80&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
    	parallel -j 4 "wget -nc -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}GLBy0.08_930_FMRC_RUN_${lastAvailDate}T12:00:00Z?var=water_u&var=water_v&north=85.0000&west=0&east=180&south=-80&horizStride=1&time=${date}T{}%3A00%3A00Z&vertCoord=&addLatLon=true&accept=netcdf4'" ::: {00..21..3}


    	##  Check for bad downloads
    	redo=0
    	for f in *.nc; do
    	    ncdump -h $f > /dev/null
    	    if [[ $? -ne 0 ]]; then
    		redo=1
    		rm $f
    	    fi
    	done

	c=$((c+1))
    done

    
    ##################################################
    ##  Average depth & nc -> tiles
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    for dateHr in `ls *_west.nc | sed 's/HYCOM_Currents_\(.*\)_west\.nc/\1/'`; do
        python3 ${HERE}/scripts/cnv.py ${dateHr}
    done


    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete


    ##################################################
    ##  Process and backup
    backJobs &


    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    echo "${HERE} ${lastAvailDate} done." | mail -s "processing log" tb4764@mun.ca
    
fi
