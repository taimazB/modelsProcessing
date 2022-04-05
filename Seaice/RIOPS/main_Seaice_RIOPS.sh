#!/bin/bash
export ftpLink="https://dd.meteo.gc.ca/model_riops/netcdf/forecast/polar_stereographic/2d/00/"

############################################################################

export HERE=${HOME}/Projects/data/Seaice/RIOPS
export remote=taimazhome.ddns.net
export tiles=${remote}:/media/taimaz/mapTiles/Seaice/RIOPS/tiles
export ncArchive=/media/taimaz/14TB/Seaice/RIOPS/nc


curl ${ftpLink}048/ > ${HERE}/files
export lastAvailDate=`grep MSC_RIOPS_IICECONC_SFC_PS5km ${HERE}/files | tail -1 | sed 's/.*href=\"\(.*\)T00Z.*\".*/\1/'`
lastDlDate=`cat ${HERE}/.lastAvailDate`
rm ${HERE}/files


############################################################################
##  FUNCTIONS

function log() {
    echo $1 >> ${HOME}/Projects/data/log
    echo $1 | mail -s "Processing log" tb4764@mun.ca
}

function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    dlLink="${ftpLink}${hr}/${lastAvailDate}T00Z_MSC_RIOPS_IICECONC_SFC_PS5km_P${hr}.nc"
    axel -c -a -n 50 -o ${HERE}/nc/ ${dlLink}
}
export -f dl


function regrid {
    hr=$1
    ##  Remap to lat,lon coordinate
    cdo -s -O remapbil,${HERE}/scripts/grid.txt ${lastAvailDate}T00Z_MSC_RIOPS_IICECONC_SFC_PS5km_P${hr}.nc CMC_RIOPS_Seaice_${lastAvailDate}_${hr}.nc
    # rm ${lastAvailDate}T00Z_MSC_RIOPS_IICECONC_SFC_PS5km_P${hr}.nc
}
export -f regrid


function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr}
}
export -f py


function backJobs(){
    #####################################################
    ##  Archive
    cd ${HERE}
    rm ${HERE}/nc/2*
    rm ${HERE}/nc/CMC_RIOPS_Seaice_*_0{24..45..3}*
    # Loop until rsyncs are complete (overcome rsync connection drops)
    resync=1
    while [[ ${resync} -ne 0 ]]; do
	resync=0
	##  Archive processed and original nc files
	rsync -auq --timeout=10000 ${HERE}/nc/ ${ncArchive}
	resync=`echo "${resync} + $?" | bc`
	##  Copy tiles to tile server
	rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles/ ${tiles}
	resync=`echo "${resync} + $?" | bc`
    done

    ##  Update list of available dateTimes
    ssh -p 4412 ${remote} <<EOF
ls /media/taimaz/mapTiles/Seaice/RIOPS/tiles | cut -d_ -f3,4 > /media/taimaz/mapTiles/Seaice/RIOPS/dateTimes
EOF
    
    log "`date` - Seaice RIOPS - rsynched - DONE"
}


##  FUNCTIONS
############################################################################


if [[ ! -z ${lastAvailDate} ]] && [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    log "`date` - MLD RIOPS - STARTED"
    rm -r ${HERE}/nc/ ${HERE}/tiles/
    mkdir -p ${HERE}/nc
    mkdir ${HERE}/tiles/
	
    cd ${HERE}/nc/

    echo -e "\tDownloading ..." ; parallel -j 4 "dl {}" ::: {000..047..3}
    log "`date` - Seaice RIOPS - Downloaded"
    echo -e "\tRegridding ..." ; parallel -j 6 "regrid {}" ::: {000..047..3}
    log "`date` - Seaice RIOPS - cdo done"
    echo -e "\tProcessing ..."
    for hr in {000..047..3}; do
        py ${hr}
    done
    log "`date` - Seaice RIOPS - Converted"


    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete

    
    ##################################################
    ##  Process and backup
    backJobs &


    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
