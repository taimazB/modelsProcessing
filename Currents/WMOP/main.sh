#!/bin/bash
year=`date +%Y`
month=`date +%m`
day=`date +%d`
lastAvailDate=${year}${month}${day}
export dlLink="https://thredds.socib.es/thredds/fileServer/operational_models/oceanographical/hydrodynamics/wmop_surface/${year}/${month}/roms_wmop_surface_${lastAvailDate}.nc"

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/Currents/WMOP/
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Currents/WMOP/tiles
export pathPlanning=${remote}:/media/taimaz/mapTiles/Currents/WMOP/PPnc


if curl --head --silent --fail ${dlLink} 2> /dev/null; then
    lastDlDate=`cat ${HERE}/.lastAvailDate`

    if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
	rm -r ${HERE}nc/
	mkdir ${HERE}/nc/
	cd ${HERE}/nc/
	axel -o WMOP_Currents_${lastAvailDate}.nc ${dlLink}
	

	#####################################################
	##  nc -> tiles
	rm -r ${HERE}/tiles/
	mkdir ${HERE}/tiles/
	cd ${HERE}/nc/
	python3 ${HERE}/scripts/cnv.py ${lastAvailDate}


	##################################################
	##  Remove empty tile directories
	cd ${HERE}/tiles/
	find . -type d -empty -delete


	##################################################
	##  Copy jpg's to server
	rsync -aurz ${HERE}/tiles root@${IP}:/mnt/data/models/Currents/WMOP/

	
	##################################################
	##  Backup tiles
	cd ${HERE}
	rsync -aurq ${HERE}/tiles ${archive}/ &


	#####################################################
	##  Archeive original files
	cd ${HERE}
	mv ${HERE}/nc/*.nc ${archive}/nc/
	

	echo ${lastAvailDate} > ${HERE}/.lastAvailDate
	
    fi
fi
