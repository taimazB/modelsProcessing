#!/bin/bash

field=Seaice
model=Barents
export HERE=${HOME}/Projects/data/${field}/${model}
export ncDir=/media/taimaz/14TB/.tmp/${model}
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/Seaice/RIOPS/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/${field}/${model}/tiles
export ncArchive=/media/taimaz/14TB/${field}/${model}/nc


export lastDlDate=`cat ${HERE}/.lastDlDate`
export lastProcessDate=`cat ${HERE}/.lastProcessDate`

if [[ ! -e ${ncDir} ]] || [[ ${lastDlDate} == ${lastProcessDate} ]]; then
    exit
fi


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.processInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function regrid {
    ##  Extract seaice
    ncks -v ice_concentration ${ncDir}/barents_zdepth_${lastDlDate}T00Zm00_FC.nc ${HERE}/nc//${field}_${model}_${lastDlDate}.nc
    
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${HERE}/nc/${field}_${model}_${lastDlDate}.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_regrid.nc
    # rm ${lastAvailDate}T00Z_MSC_RIOPS_IICECONC_SFC_PS5km_P${hr}.nc
}
export -f regrid

function py {
    python3 ${HERE}/scripts/cnv.py ${lastDlDate}
}
export -f py

function backJobs(){
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Archive processed and original nc files
	# rsync -auq --timeout=10000 ${ncDir}/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/${field}/${model}/lastProcessed
EOF
    
    # rm -r ${ncDir}/
    rm -r ${HERE}/tiles
}

##  FUNCTIONS
############################################################################


rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
mkdir ${HERE}/nc/

cd ${ncDir}
log "`date` - Rgd S ${field} ${model}"
regrid
log "`date` - Rgd E ${field} ${model}"

cd ${HERE}/nc
log "`date` - Cnv S ${field} ${model}"
py
log "`date` - Cnv E ${field} ${model}"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Process and backup
backJobs &


echo ${lastDlDate} > ${HERE}/.lastProcessDate
