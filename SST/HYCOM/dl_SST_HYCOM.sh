#!/bin/bash
export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

############################################################################

export HERE=${HOME}/Projects/data/SST/HYCOM
export ncDir=/media/taimaz/14TB/.tmp/TS_HYCOM
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/SST/HYCOM/tiles
# export ncArchive=/media/taimaz/14TB/SST/HYCOM/nc

if [[ -e ${ncDir} ]]; then
    exit
fi

files=(`curl -l "ftp://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts/"`)
noOfFiles=${#files[@]}
export lastAvailDate=`echo ${files[$((noOfFiles-1))]} | cut -d_ -f4 | sed 's/12$//'`
lastAvailTime=`echo ${files[$((noOfFiles-1))]} | cut -d_ -f5 | sed 's/t0*//'`
##  Only download if last t = 180
# if [[ ${lastAvailTime} -lt 72 ]]; then
#     exit
# fi
lastDlDate=`cat ${HERE}/.lastDlDate`
lastDlTime=`cat ${HERE}/.lastDlTime`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/.dlInProgress
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl(){
    t=$1
    date=`date -d "${lastAvailDate} +$((t+12)) hour" +%Y%m%d_%H`
    wget -nc -O HYCOM_TS_${date}.nc "${ftpLink}/hycom_glby_930_${lastAvailDate}12_t`printf %03d ${t}`_ts3z.nc"
}
export -f dl

##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]]; then
    if [[ ${lastAvailDate} != ${lastDlDate} ]]; then
	log "`date` - SST HYCOM Download STARTED"
	mkdir ${ncDir}/
	cd ${ncDir}
	parallel -j 8 'dl {}' ::: `seq 0 3 ${lastAvailTime}`
	log "`date` - SST HYCOM Download DONE"
    elif [[ ${lastAvailTime} != ${lastDlTime} ]]; then
        log "`date` - SST HYCOM Download STARTED"
        mkdir ${ncDir}/
        cd ${ncDir}
        parallel -j 8 'dl {}' ::: `seq ${lastDlTime} 3 ${lastAvailTime}`
        log "`date` - SST HYCOM Download DONE"
    fi
    
    echo ${lastAvailDate} > ${HERE}/.lastDlDate
    echo ${lastAvailTime} > ${HERE}/.lastDlTime
    echo ${lastAvailDate} > ${ncDir}/.lastDlDate ## For others
    echo ${lastAvailTime} > ${ncDir}/.lastDlTime ## For others
fi
