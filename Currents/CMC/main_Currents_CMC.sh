#!/bin/bash
export ftpLink="https://dd.weather.gc.ca/model_gem_regional/coupled/gulf_st-lawrence/grib2/"

############################################################################

export HERE=${HOME}/Projects/data/Currents/CMC
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Currents/CMC/tiles
export ncArchive=/media/taimaz/14TB/Currents/CMC/nc
export pathPlanning=${remote}:/media/taimaz/mapTiles/Currents/CMC/PPnc

rm ${HERE}/availDates
for modelHr in 00 06 12 18; do
    curl ${ftpLink}${modelHr}/048/ > ${HERE}/files
    lastAvailDate=$(grep CMC_coupled-rdps-stlawrence-ocean files | tail -1 | sed 's/.*href=\"CMC_coupled-rdps-stlawrence-ocean_latlon0\.02x0\.03_\(.*\)_P048.*\".*/\1/')
    echo $lastAvailDate >> ${HERE}/availDates
done
export lastAvailDate=`sort -g ${HERE}/availDates | tail -1 | cut -c1-8`
export lastAvailHour=`sort -g ${HERE}/availDates | tail -1 | cut -c9-10`
lastDlDate=$(cat ${HERE}/.lastAvailDate)
rm ${HERE}/files ${HERE}/availDates


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    dlLink="${ftpLink}${lastAvailHour}/${hr}/CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}${lastAvailHour}_P${hr}.grib2"
    axel -c -a -n 50 -o ${HERE}/nc/ ${dlLink}
}
export -f dl

function grib2nc {
    hr=$1
    cdo -f nc copy CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}${lastAvailHour}_P${hr}.grib2 CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}${lastAvailHour}_P${hr}.nc
    rm CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastAvailDate}${lastAvailHour}_P${hr}.grib2
}
export -f grib2nc

function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${lastAvailHour} ${hr}
}
export -f py

##  FUNCTIONS
############################################################################


function backJobs() {
    ##################################################
    ##  Path Planning time averaged & 24 time steps forecast files
    cd ${HERE}/nc/
    cdo -O ensmean ${HERE}/nc/CMC_Currents_${lastAvailDate}_*.nc ${HERE}/nc/CMC_Currents_avgTime.nc


    #####################################################
    ##  Path Planning hindcast file:  7 days before today
    ##  Since this is a surface model, hindcast and nc directories would contain same files, so no hindcast directory
    # cd ${archive}/nc/
    # cdo -O ensmean $(ls HYCOM_Currents_avgDepth_*.nc | tail -56) ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc
    # cdo -O ensstd $(ls HYCOM_Currents_avgDepth_*.nc | tail -56) ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc
    # ncrename -O -v u,u_mean -v v,v_mean ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc
    # ncrename -O -v u,u_std -v v,v_std ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc
    # cdo -O merge ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc ${HERE}/nc/HYCOM_Currents_avgDepth_avgstdTime_7d.nc
    # rm ${HERE}/nc/HYCOM_Currents_avgDepth_avgTime_7d.nc ${HERE}/nc/HYCOM_Currents_avgDepth_stdTime_7d.nc
    #####################################################
    ##  Copy to server
    # mv ${HERE}/nc/CMC_Currents_avgstdTime_7d.nc ${pathPlanning}/hindcast/


    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy processed nc files to path planning server
	rsync -auq --timeout=10000 --delete -e 'ssh -p 4412' ${HERE}/nc/ ${pathPlanning}
	resync=`echo "${resync} + $?" | bc`
	##  Archive processed nc files
	rsync -auq --timeout=10000 ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/Currents/CMC/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/Currents/CMC/dateTimes
EOF
    
    log "`date` - Currents CMC - rsynched - DONE"
}


# if [[ ${lastAvailDate}${lastAvailHour} != ${lastDlDate} ]]; then
if [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    log "`date` - Currents CMC - STARTED"
    rm -r ${HERE}/nc/
    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    echo -e "\tDownloading ..."
    parallel -j 4 "dl {}" ::: {001..048..1}
    echo -e "\tRegridding ..."
    parallel -j 4 "grib2nc {}" ::: {001..048..1}
    log "`date` - Currents CMC - Downloaded and grib->nc"
    
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    echo -e "\tProcessing ..."
    for hr in {1..48..1}; do
	py ${hr}
    done
    log "`date` - Currents CMC - Converted"
    
    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Path Planning
    backJobs &


    # echo ${lastAvailDate}${lastAvailHour} >${HERE}/.lastAvailDate
    echo ${lastAvailDate} >${HERE}/.lastAvailDate

fi
