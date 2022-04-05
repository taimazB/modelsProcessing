#!/bin/bash

HERE=${HOME}/Projects/OceanGNS/data/Currents/WMOP-surface/
archive=/media/taimaz/14TB/Currents/WMOP-surface


year=`date +%Y`
month=`date +%m`
day=`date +%d`
lastAvailDate=${year}${month}${day}
dlLink="https://thredds.socib.es/thredds/fileServer/operational_models/oceanographical/hydrodynamics/wmop_surface/${year}/${month}/roms_wmop_surface_${lastAvailDate}.nc"

if curl --head --silent --fail ${dlLink} 2> /dev/null; then
    lastDlDate=`cat ${HERE}/.lastAvailDate`

    if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
	mkdir ${HERE}/nc/
	# mkdir ${HERE}/png/
	# mkdir ${HERE}/jpg/

	
	cd ${HERE}/nc/
	axel -o WMOP-surface_Currents_surface_${lastAvailDate}.nc ${dlLink}
    

	#########################
	##  nc to image
	# cd ${HERE}/nc/
	# python3 ${HERE}/scripts/cnv.py ${lastAvailDate}


	##################################################
	##  Convert png to jpg  (png's are too big)
	# cd ${HERE}/png/
	# ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
	# rm -r ${HERE}/png/ &

	# cd ${HERE}/jpg/
	# for f in WMOP-surface_Currents_*.jpg; do
        #     dir=`basename $f .jpg`
        #     mkdir ${dir}
        #     mv ${dir}*.jpg ${dir}
	# done
    
    
	##################################################
	##  Copy jpg's to server
	# rsync -aurz ${HERE}/jpg taimaz@68.183.206.70:/mnt/data/models/Currents/WMOP-surface/

    
	#####################################################
	##  Backup jpg's
	# cd ${HERE}
	# rsync -aur ${HERE}/jpg ${archive}/
	# rm -r ${HERE}/jpg &
	mv ${HERE}/nc/* ${archive}/nc/
	rm -r ${HERE}/nc/
	
	
	echo ${lastAvailDate} > ${HERE}/.lastAvailDate
	
    fi
fi
