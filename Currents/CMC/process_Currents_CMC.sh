#!/bin/bash

export HERE=${HOME}/Projects/data/Currents/CMC
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/Currents/CMC/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/Currents/CMC/tiles
export ncArchive=/media/taimaz/14TB/Currents/CMC/nc
export pathPlanning=${remote}:/media/taimaz/mapTiles/Currents/CMC/PPnc


export lastDlDate=`cat ${HERE}/.lastDlDate`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`
export lastDlHour=00

if [[ ! -e ${HERE}/nc ]] || [[ ${lastDlDate} == ${lastProcessDate} ]]; then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function grib2nc {
    hr=$1
    cdo -f nc copy CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastDlDate}${lastDlHour}_P${hr}.grib2 CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastDlDate}${lastDlHour}_P${hr}.nc
    rm CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_${lastDlDate}${lastDlHour}_P${hr}.grib2
}
export -f grib2nc

function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastDlDate} ${lastDlHour} ${hr}
}
export -f py

function backJobs() {
    ##################################################
    ##  Path Planning time averaged & 24 time steps forecast files
    cd ${HERE}/nc/
    cdo -O ensmean ${HERE}/nc/CMC_Currents_${lastDlDate}_*.nc ${HERE}/nc/CMC_Currents_avgTime.nc


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
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Currents/CMC/lastProcessed
EOF

    rm -r ${HERE}/nc
    rm -r ${HERE}/tiles
    
    # log "`date` - Currents CMC Rsync DONE."
}

##  FUNCTIONS
############################################################################


rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/

log "`date` - Currents CMC Regrid STARTED"
cd ${HERE}/nc/
parallel -j 4 "grib2nc {}" ::: {001..048..1}
log "`date` - Currents CMC Regrid DONE -> Convertion STARTED"
for hr in {1..48..1}; do
    py ${hr}
done
log "`date` - Currents CMC Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Path Planning
backJobs &


echo ${lastDlDate} >${HERE}/.lastProcessDate
