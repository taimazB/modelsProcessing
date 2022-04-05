#!/bin/bash

export HERE=${HOME}/Projects/data/Currents/RIOPS
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/Currents/RIOPS/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/Currents/RIOPS/tiles
export pathPlanning=${remote}:/home/taimaz/Projects/server/public/pathPlanning/gnt/Datasets/RIOPS/forecast
export ncArchive=/media/taimaz/14TB/Currents/RIOPS/nc


export lastDlDate=`cat ${HERE}/.lastDlDate`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`

if [[ ! -e ${HERE}/nc ]] || [[ ${lastDlDate} == ${lastProcessDate} ]]; then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function regrid {
    hr=$1
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${lastDlDate}T00Z_MSC_RIOPS_VOZOCRTX_DBS-all_PS5km_P${hr}.nc CMC_RIOPS_ux_${lastDlDate}_${hr}.nc
    
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${lastDlDate}T00Z_MSC_RIOPS_VOMECRTY_DBS-all_PS5km_P${hr}.nc CMC_RIOPS_vy_${lastDlDate}_${hr}.nc
}
export -f regrid

function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastDlDate} ${hr}
}
export -f py


function backJobs(){
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    cdo -O ensmean ${HERE}/nc/PP/RIOPS_Currents_avgDepth_${lastDlDate}_*.nc ${HERE}/nc/PP/RIOPS_Currents_avgDepth_avgTime.nc
    

    #####################################################
    ##  Path Planning hindcast file:  7 days before today (7*24 files)
    # cd ${archive}/hindcast/
    # cdo -O ensmean `ls RIOPS_Currents_avgDepth_2*.nc | tail -168` ${HERE}/nc/RIOPS_Currents_avgDepth_avgTime_7d.nc
    # cdo -O ensstd `ls RIOPS_Currents_avgDepth_2*.nc | tail -168` ${HERE}/nc/RIOPS_Currents_avgDepth_stdTime_7d.nc
    # ncrename -O -v u,u_mean -v v,v_mean ${HERE}/nc/RIOPS_Currents_avgDepth_avgTime_7d.nc
    # ncrename -O -v u,u_std -v v,v_std ${HERE}/nc/RIOPS_Currents_avgDepth_stdTime_7d.nc
    # cdo -O merge ${HERE}/nc/RIOPS_Currents_avgDepth_avgTime_7d.nc ${HERE}/nc/RIOPS_Currents_avgDepth_stdTime_7d.nc ${HERE}/nc/RIOPS_Currents_avgDepth_avgstdTime_7d.nc
    # rm ${HERE}/nc/RIOPS_Currents_avgDepth_stdTime_7d.nc ${HERE}/nc/RIOPS_Currents_avgDepth_avgTime_7d.nc
    # cp ${pathPlanning}/forecast/RIOPS_Currents_avgDepth_2*.nc ${archive}/hindcast/
    #####################################################
    ##  Copy to path planning
    # mv ${HERE}/nc/RIOPS_Currents_avgDepth_avgstdTime_7d.nc ${pathPlanning}/hindcast/


    #####################################################
    ##  Zip original nc files
    # cd ${HERE}/nc/
    # ls CMC_RIOPS_*{000..021..3}.nc | parallel 'tar czf {}.tar.gz {}'
    
	
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
        ##  Copy processed nc files to path planning server
	rsync -auq --partial --timeout=10000 -e 'ssh -p 4412' ${HERE}/nc/PP/ ${pathPlanning}
	resync=`echo "${resync} + $?" | bc`
	##  Archive processed and original nc files
	rsync -auq --timeout=10000 --exclude 'PP' ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Currents/RIOPS/lastProcessed
EOF

    rm -r ${HERE}/nc
    rm -r ${HERE}/tiles

    # log "`date` - Currents RIOPS Rsync DONE."
}


##  FUNCTIONS
############################################################################


mkdir ${HERE}/nc/PP
rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
cd ${HERE}/nc/

log "`date` - Currents RIOPS Regrid STARTED"
parallel -j 6 "regrid {}" ::: {000..047..3}
log "`date` - Currents RIOPS Regrid DONE -> Convertion STARTED"
for hr in {000..047..3}; do
    py ${hr}
done
log "`date` - Currents RIOPS Convertion DONE"

rm ${HERE}/nc/*VOMECRTY* ${HERE}/nc/*VOZOCRTX*


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete

    
##################################################
##  Process and backup
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
