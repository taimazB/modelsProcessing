#!/bin/bash

export field=Currents
export model=Barents
export HERE=${HOME}/Projects/data/${field}/${model}
export ncDir=/media/taimaz/14TB/.tmp/Barents
export remote=taimazhome.ddns.net
# export tiles=${remote}:/media/taimaz/mapTiles/Currents/CMC/tiles
export tiles=${remote}:/home/taimaz/Projects/server/public/mapTiles/${field}/${model}/tiles
# export ncArchive=/media/taimaz/14TB/${field}/${model}/nc
# export pathPlanning=${remote}:/media/taimaz/mapTiles/${field}/${model}/PPnc


export lastDlDate=`cat ${ncDir}/.lastDlDate`
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
    ##  Extracting levels here to reduce regridding costs
    case=$1
    if [[ ${case} -eq 1 ]]; then
	cdo -O sellevel,0 ${HERE}/nc/${field}_${model}_${lastDlDate}.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_surface.nc
	cdo -s -O remapbil,${HERE}/scripts/grid.txt ${HERE}/nc/${field}_${model}_${lastDlDate}_surface.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_surface_regrid.nc
    elif [[ ${case} -eq 2 ]]; then
	cdo -O sellevel,25,50,75,100,150,200 ${HERE}/nc/${field}_${model}_${lastDlDate}.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_0020-0200.nc
	cdo -s -O remapbil,${HERE}/scripts/grid.txt ${HERE}/nc/${field}_${model}_${lastDlDate}_0020-0200.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_0020-0200_regrid.nc
    elif [[ ${case} -eq 3 ]]; then
	cdo -O sellevel,50,75,100,150,200,250,300,500,1000 ${HERE}/nc/${field}_${model}_${lastDlDate}.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_0050-1000.nc
	cdo -s -O remapbil,${HERE}/scripts/grid.txt ${HERE}/nc/${field}_${model}_${lastDlDate}_0050-1000.nc ${HERE}/nc/${field}_${model}_${lastDlDate}_0050-1000_regrid.nc
    fi
}
export -f regrid

function py {
    case=$1
    if [[ ${case} -eq 1 ]]; then
	depth=surface
    elif [[ ${case} -eq 2 ]]; then
	depth='0020-0200'
    elif [[ ${case} -eq 3 ]]; then
	depth='0050-1000'
    fi
    python3 ${HERE}/scripts/cnv.py ${lastDlDate} ${depth}
}
export -f py

function backJobs() {
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy processed nc files to path planning server
	# rsync -auq --timeout=10000 --delete -e 'ssh -p 4412' ${HERE}/nc/ ${pathPlanning}
	# resync=`echo "${resync} + $?" | bc`
	##  Archive processed nc files
	# rsync -auq --timeout=10000 ${HERE}/nc/ ${ncArchive}
	# resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
date -u +%Y%m%dT%H%M%S > /home/taimaz/Projects/server/public/mapTiles/Currents/Barents/lastProcessed
EOF

    rm -r ${ncDir}  ##  Temperature next
    rm -r ${HERE}/nc
    rm -r ${HERE}/tiles
    
    # log "`date` - Currents CMC Rsync DONE."
}

##  FUNCTIONS
############################################################################


rm -r ${HERE}/tiles/
mkdir ${HERE}/tiles/
mkdir ${HERE}/nc/
cd ${ncDir}


log "`date` - Ext S ${field} ${model}"
##  Extract u,v
ncks -v u,v ${ncDir}/barents_zdepth_${lastDlDate}T00Zm00_FC.nc ${HERE}/nc/${field}_${model}_${lastDlDate}.nc
log "`date` - Ext E ${field} ${model}"

cd ${HERE}/nc/
log "`date` - Rgd S ${field} ${model}"
parallel 'regrid {}' ::: {1..3}
log "`date` - Rgd E ${field} ${model}"

log "`date` - Cnv S ${field} ${model}"
parallel 'py {}' ::: {1..3}
log "`date` - Cnv E ${field} ${model}"


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Path Planning
backJobs &


echo ${lastDlDate} >${HERE}/.lastProcessDate
