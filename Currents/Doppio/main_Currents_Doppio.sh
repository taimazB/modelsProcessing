#!/bin/bash
export ftpLink='https://tds.marine.rutgers.edu/thredds/ncss/roms/doppio/2017_da/his/History_Best?var=ubar_eastward&var=vbar_northward&horizStride=1&timeStride=1&vertCoord=&accept=netcdf4'

############################################################################

export HERE=${HOME}/Projects/data/Currents/Doppio
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Currents/Doppio/tiles
export pathPlanning=${remote}:/home/taimaz/Projects/server/public/pathPlanning/gnt/Datasets/Doppio/forecast
# export ncArchive=/media/taimaz/14TB/Currents/Doppio/nc


rm -r ${HERE}/nc
mkdir ${HERE}/nc

today=`date +%Y%m%d`
startDate=`date +%Y-%m-%d`
endDate=`date -d "+10 days" +%Y-%m-%d`
dlLink="${ftpLink}&time_start=${startDate}T00%3A00%3A00Z&time_end=${endDate}T23%3A00%3A00Z"
axel -a -n 50 -o ${HERE}/nc/tmp.nc "${dlLink}"
lastAvailDate=`cdo info ${HERE}/nc/tmp.nc | grep -v Date | tail -1 | awk '{print $3}'`
lastAvailTime=`cdo info ${HERE}/nc/tmp.nc | grep -v Date | tail -1 | awk '{print $4}'`
lastAvailDateTime="${lastAvailDate}_${lastAvailTime}"
lastDlDateTime=`cat ${HERE}/.lastAvailDateTime`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}


function regrid {
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${HERE}/nc/tmp.nc ${HERE}/nc/Doppio_Currents_${today}.nc
}
export -f regrid


function backJobs(){
    ##################################################
    ##  Path Planning time averaged & 8 time steps forecast files
    # cd ${HERE}/nc/avg
    # cdo -O ensmean ${HERE}/nc/avg/RIOPS_Currents_avgDepth_${lastAvailDate}_*.nc ${HERE}/nc/avg/RIOPS_Currents_avgDepth_avgTime.nc
    

    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
        ##  Copy processed nc files to path planning server
	# rsync -auq --partial --timeout=10000 --delete -e 'ssh -p 4412' ${HERE}/nc/avg/ ${pathPlanning}
	# resync=`echo "${resync} + $?" | bc`
	##  Archive processed and original nc files
	# rsync -auq --timeout=10000 ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/Currents/Doppio/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/Currents/Doppio/dateTimes
EOF
    
    log "`date` - Currents Doppio - rsynched - DONE"
}


##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDateTime} ]] && [[ ${lastAvailDateTime} != ${lastDlDateTime} ]]; then

    log "`date` - Currents Doppio - STARTED"
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/

    cd ${HERE}/nc/

    echo -e "\tRegridding ..." ; regrid
    log "`date` - Currents Doppio - cdo done"
    echo -e "\tProcessing ..."
    python3 ${HERE}/scripts/cnv.py ${today}
    log "`date` - Currents Doppio - Converted"

    rm ${HERE}/nc/tmp.nc

    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Process and backup
    backJobs &


    echo ${lastAvailDateTime} > ${HERE}/.lastAvailDateTime
    
fi
