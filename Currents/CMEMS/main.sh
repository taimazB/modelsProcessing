#!/bin/bash
export ftpLink="ftp://nrt.cmems-du.eu/Core/MEDSEA_ANALYSISFORECAST_PHY_006_013/med-cmcc-cur-an-fc-hts"

############################################################################

export HERE=${HOME}/Projects/data/Currents/CMEMS
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Currents/CMEMS/tiles
export pathPlanning=${remote}:/media/taimaz/mapTiles/Currents/CMEMS/PPnc
export ncArchive=/media/taimaz/14TB/Currents/CMEMS/nc


user="tbahadory"
pass="pass4OceanGNS@"

year=`date +%Y`
month=`date +%m`
day=`date +%d`

dlLink="${ftpLink}/${year}/${month}/"

files=(`curl -u ${user}:${pass} ${dlLink} | awk '{print $9}'`)
lastAvailDate=`echo ${files[-1]} | cut -d_ -f1`
lastDlDate=`cat ${HERE}/.lastAvailDate`


############################################################################
##  FUNCTIONS

function py {
    file=$1
    iTime=$2
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${file} ${iTime}
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
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles ${tiles}
	resync=`echo "${resync} + $?" | bc`
	##  Copy original nc files to archive
	rsync -auq --partial --timeout=10000 ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
    done
}

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    rm -r ${HERE}/nc/ ${HERE}/tiles/
    mkdir ${HERE}/nc/ ${HERE}/tiles/
    cd ${HERE}/nc/
    
    for file in ${files[@]}; do
	date=`echo ${file} | cut -d_ -f1`
	mode=`echo ${file} | cut -d_ -f3 | cut -d- -f1`
	savedFile=`ssh -p 4412 taimazhome.ddns.net ls /media/taimaz/14TB/Currents/CMEMS/nc/${date}_*.nc 2>/dev/null`

	if [[ ! -n ${savedFile} ]]; then
	    wget --user ${user} --password ${pass} ${dlLink}${file}
	    for iTime in {0..23..1}; do
		py ${file} ${iTime}
	    done
	elif [[ ${mode} != an ]]; then
	    wget --user ${user} --password ${pass} ${dlLink}${file}
	    for iTime in {0..23..1}; do
		py ${file} ${iTime}
	    done
	fi
    done

    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Path Planning
    backJobs &

    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    echo "${HERE} ${lastAvailDate} done." | mail -s "processing log" tb4764@mun.ca
    
fi
