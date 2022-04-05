#!/bin/bash
##  Do not use more than 10 concurrent connections per IP address downloading from ftp.hycom.org

export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

############################################################################

export HERE=${HOME}/Projects/data/Currents/HYCOM
export tmpDl=/media/taimaz/14TB/.tmp/Currents_HYCOM
export remote=taimaz@taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Currents/HYCOM/tiles
export pathPlanning=${remote}:/home/taimaz/Projects/server/public/pathPlanning/gnt/Datasets/HYCOM/forecast
export ncArchive=/media/taimaz/14TB/Currents/HYCOM/nc
export OPASSnc=${remote}:/media/taimaz/mapTiles/Currents/HYCOM/OPASSnc


files=(`curl -l "ftp://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts/"`)
noOfFiles=${#files[@]}
export lastAvailDate=`echo ${files[$((noOfFiles-1))]} | cut -d_ -f4 | sed 's/12$//'`
lastAvailTime=`echo ${files[$((noOfFiles-1))]} | cut -d_ -f5 | sed 's/t0*//'`
##  Only download if last t = 180
if [[ ${lastAvailTime} -lt 72 ]]; then
    exit
fi
lastDlDate=`cat ${HERE}/.lastAvailDate`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl(){
    t=$1
    date=`date -d "${lastAvailDate} +$((t+12)) hour" +%Y%m%d_%H`
    wget -nc -O HYCOM_Currents_${date}.nc "${ftpLink}/hycom_glby_930_${lastAvailDate}12_t`printf %03d ${t}`_uv3z.nc"
}
export -f dl


function backJobs(){
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    date=`date -d "${lastAvailDate} +1 day" +%Y%m%d`
    cdo -O ensmean ${tmpDl}/PP/HYCOM_Currents_avgDepth_${date}*.nc ${tmpDl}/PP/HYCOM_Currents_avgDepth_avgTime.nc


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
	rsync -auq --partial --timeout=10000 --delete -e 'ssh -T -p 4412' ${tmpDl}/PP/ ${pathPlanning}
	resync=`echo "${resync} + $?" | bc`
	##  Archive processed nc files
	rsync -auq --timeout=10000 ${tmpDl}/PP/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -T -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
	##  Copy original nc files to OPASSnc
	rsync -auq --timeout=10000 -e 'ssh -p 4412' ${tmpDl}/HYCOM_Currents_2*.nc ${OPASSnc}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/Currents/HYCOM/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/Currents/HYCOM/dateTimes
EOF

    
    ##  To free up space
    # rm -r ${tmpDl}/
    rm -r ${HERE}/tiles/
    log "`date` - Currents HYCOM - rsynched - DONE"
}


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    log "`date` - Currents HYCOM - STARTED"
    rm -r ${tmpDl}/
    mkdir -p ${tmpDl}/PP

    cd ${tmpDl}
    parallel -j 8 'dl {}' ::: {0..72..3}
    log "`date` - Currents HYCOM - Downloaded"
    
    
    ##################################################
    ##  Average depth & nc -> tiles
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    cd ${tmpDl}/
    for dateHr in `ls *.nc | sed 's/HYCOM_Currents_\(.*\)\.nc/\1/'`; do
        python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
    done
    log "`date` - Currents HYCOM - Converted"
    

    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete


    ##################################################
    ##  Process and backup
    backJobs &


    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
