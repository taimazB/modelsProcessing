#!/bin/bash
export ftpLink='ftps://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts'

############################################################################

export HERE=${HOME}/Projects/data/MLD/HYCOM
export tmpDl=/media/taimaz/14TB/.tmp/SUR_HYCOM
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/MLD/HYCOM/tiles
# export ncArchive=/media/taimaz/14TB/MLD/HYCOM/nc


files=(`curl -l "ftp://ftp.hycom.org/datasets/GLBy0.08/expt_93.0/data/forecasts/"`)
noOfFiles=${#files[@]}
export lastAvailDate=`echo ${files[$((noOfFiles-1))]} | cut -d_ -f4 | sed 's/12$//'`
lastAvailTime=`echo ${files[$((noOfFiles-1))]} | cut -d_ -f5 | sed 's/12$//'`
##  Only download if last t = 180
if [[ ${lastAvailTime} != "t180" ]]; then
    exit
fi
lastDlDate=`cat ${HERE}/.lastAvailDate`


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    t=$1
    date=`date -d "${lastAvailDate} +$((t+12)) hour" +%Y%m%d_%H`
    wget -nc -O HYCOM_SUR_${date}.nc "${ftpLink}/hycom_GLBy0.08_930_${lastAvailDate}12_t`printf %03d ${t}`_sur.nc"
}
export -f dl


function backJobs(){
    #####################################################
    ##  Archive
    cd ${HERE}
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/MLD/HYCOM/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/MLD/HYCOM/dateTimes
EOF
    
    log "`date` - MLD HYCOM - rsynched - DONE"
}


##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then
    log "`date` - MLD HYCOM - STARTED"

    rm -r ${tmpDl}/
    mkdir ${tmpDl}/

    cd ${tmpDl}

    echo -e "\tDownloading ..." ; parallel -j 8 "dl {}" ::: {0..180..3}
    log "`date` - MLD HYSOM - Downloaded"

    
    ##################################################
    ##  nc -> tiles    echo -e "\tProcessing ..."
    rm -r ${HERE}/tiles/
    mkdir ${HERE}/tiles/
    cd ${tmpDl}
    for f in HYCOM_*.nc; do
	dateHr=`basename $f .nc | cut -d_ -f3-4`
	python3 ${HERE}/scripts/cnv.py ${dateHr} ${HERE}
    done
    log "`date` - MLD HYCOM - Converted"


    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Process and backup
    backJobs &


    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
