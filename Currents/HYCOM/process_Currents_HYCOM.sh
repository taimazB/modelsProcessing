#!/bin/bash

export HERE=${HOME}/Projects/data/Currents/HYCOM
export ncDir=/media/taimaz/14TB/.tmp/Currents_HYCOM
export remote=taimaz@taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/Currents/HYCOM/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/Currents/HYCOM/tiles
export pathPlanning=${remote}:/home/taimaz/Projects/server/public/pathPlanning/gnt/Datasets/HYCOM/forecast
export ncArchive=/media/taimaz/14TB/Currents/HYCOM/nc
export OPASSnc=${remote}:/media/taimaz/mapTiles/Currents/HYCOM/OPASSnc


export lastDlDate=`cat ${HERE}/.lastDlDate`
export lastDlTime=`cat ${HERE}/.lastDlTime`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`
export lastProcessTime=`cat ${HERE}/.lastProcessTime`

if [[ ! -e ${ncDir} ]] || ([[ ${lastDlDate} == ${lastProcessDate} ]] && [[ ${lastDlTime} == ${lastProcessTime} ]]); then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function backJobs(){
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    date=`date -d "${lastDlDate} +1 day" +%Y%m%d`
    cdo -O ensmean ${ncDir}/PP/HYCOM_Currents_avgDepth_${date}*.nc ${ncDir}/PP/HYCOM_Currents_avgDepth_avgTime.nc


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

    ##  tar zip tiles for a faster transfer
    # cd ${HERE}
    # tar -c --use-compress-program=pigz -f tiles.tar.gz tiles

    
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy processed nc files to path planning server
	rsync -auq --partial --timeout=10000 -e 'ssh -T -p 4412' ${ncDir}/PP/ ${pathPlanning}
	resync=`echo "${resync} + $?" | bc`
	##  Archive processed nc files
	rsync -auq --timeout=10000 ${ncDir}/PP/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -T -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
	##  Copy original nc files to OPASSnc
	# rsync -auq --timeout=10000 -e 'ssh -p 4412' ${ncDir}/HYCOM_Currents_2*.nc ${OPASSnc}
	# resync=`echo "${resync} + $?" | bc`
    done


    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Currents/HYCOM/lastProcessed
EOF

    rm -r ${ncDir}/
    rm -r ${HERE}/tiles/

    # log "`date` - Currents HYCOM Rsync DONE."
}

##  FUNCTIONS
############################################################################


##################################################
##  Average depth & nc -> tiles
log "`date` - Currents HYCOM Convertion STARTED"
mkdir -p ${ncDir}/PP
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${ncDir}/
for dateHr in `ls *.nc | sed 's/HYCOM_Currents_\(.*\)\.nc/\1/'`; do
    python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
done
log "`date` - Currents HYCOM Convertion DONE"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Process and backup
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
echo ${lastDlTime} > ${HERE}/.lastProcessTime
