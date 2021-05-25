#!/bin/bash

HERE=${HOME}/Projects/OceanGNS/data/Currents/CMEMS
archive=/media/taimaz/14TB/Currents/CMEMS

user="tbahadory"
pass="pass4OceanGNS@"

year=`date +%Y`
month=`date +%m`
day=`date +%d`

link="ftp://nrt.cmems-du.eu/Core/MEDSEA_ANALYSIS_FORECAST_PHY_006_013/med00-cmcc-cur-an-fc-hts/${year}/${month}/"

files=(`curl -u ${user}:${pass} ${link} | awk '{print $9}'`)
lastAvailDate=`echo ${files[-1]} | cut -d_ -f1`
lastDlDate=`cat ${HERE}/.lastAvailDate`

if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    mkdir ${HERE}/nc/
    mkdir ${HERE}/png/
    mkdir ${HERE}/jpg/
    
    cd ${HERE}/nc/    
    for file in ${files[@]}; do
	date=`echo ${file} | cut -d_ -f1`
	mode=`echo ${file} | cut -d_ -f3 | cut -d- -f1`
	savedFile=`ls ${archive}/nc/${date}_*.nc 2>/dev/null`

	if [[ ! -n ${savedFile} ]]; then
	    wget --user ${user} --password ${pass} ${link}${file}
	    python3 ${HERE}/scripts/cnv.py ${file}
	elif [[ ${mode} != an ]]; then
	    rm ${savedFile}
	    wget --user ${user} --password ${pass} ${link}${file}
	    python3 ${HERE}/scripts/cnv.py ${file}
	fi
    done

    
    ##################################################
    ##  Convert png to jpg  (png's are too big)
    cd ${HERE}/png/
    ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
    rm -r ${HERE}/png/

    cd ${HERE}/jpg/
    for f in CMEMS_Currents_*.jpg; do
        dir=`echo $f | cut -d_ -f1-4`
        mkdir ${dir} 2>/dev/null
        mv ${dir}*.jpg ${dir} 2>/dev/null
    done

    
    ##################################################
    ##  Copy jpg's to server
    rsync -aur ${HERE}/jpg taimaz@159.203.6.104:/mnt/data/models/Currents/CMEMS/

    
    ##################################################
    ##  Backup files
    cd ${HERE}
    rsync -aur ${HERE}/jpg ${archive}/
    rm -r ${HERE}/jpg &
    mv ${HERE}/nc/* ${archive}/nc/
    rm -r ${HERE}/nc/ &
    
    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
fi
