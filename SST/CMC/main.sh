#!/bin/bash

############################################################################

export HERE=${HOME}/Projects/data/SST/CMC
export ncDir=${HOME}/Projects/data/Currents/CMC/nc
export archive=taimazhome.ddns.net:/media/taimaz/14TB/SST/CMC/

rm -r ${HERE}/nc
mkdir ${HERE}/nc
ln -s ${ncDir}/CMC_Currents_2*.nc ${HERE}/nc
lastAvailDate=`ls nc/CMC_Currents_2*.nc | tail -1 | cut -d_ -f3`
lastDlDate=`cat ${HERE}/.lastAvailDate`


if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    ##################################################
    ##  nc -> tiles
    rm -r ${HERE}/tiles
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    for f in *.nc; do
	dateTime=`basename $f .nc | cut -d_ -f3,4`
	python3 ${HERE}/scripts/cnv.py ${dateTime}
    done
        
    
    ##################################################
    ##  Remove empty tile directories
    cd ${HERE}/tiles/
    find . -type d -empty -delete


    ##################################################
    ##  Archive
    function backJobs {
	cd ${HERE}
	# Loop until rsyncs are complete (overcome rsync connection drops)
	resync=1
	while [[ ${resync} -ne 0 ]]; do
	    resync=0
	    ##  Copy tiles to tile server
	    rsync -aurq --timeout=10000 -e 'ssh -p 4412' ${HERE}/tiles ${archive}/
	    resync=`echo "${resync} + $?" | bc`
	    ##  Copy nc files to archive
	    rsync -auq --timeout=10000 -e 'ssh -p 4412' ${HERE}/nc/*.nc ${archive}/nc/
	    resync=`echo "${resync} + $?" | bc`
	done
    }
    backJobs &
    
    
    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    echo "${HERE} ${lastAvailDate} done." | mail -s "processing log" tb4764@mun.ca
    
fi
