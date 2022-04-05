#!/bin/bash
mainLink='https://podaac-opendap.jpl.nasa.gov/opendap/hyrax/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/'
IP='143.110.215.10'

############################################################################

export HERE=${HOME}/Projects/data/SST/JPLMUR41
export archive=taimazhome.ddns.net:/media/taimaz/14TB/SST/JPLMUR41/

year=`date +%Y`
lastAvailDay=$1
lastAvailDate=`date -d "${year}-01-01 +$(echo "${lastAvailDay}-1" | bc) day" +%Y%m%d`
month=`date -d "${lastAvailDate}" +%m`
day=`date -d "${lastAvailDate}" +%d`


    rm -r ${HERE}/nc/ ${HERE}/tiles/

    mkdir ${HERE}/nc/
    cd ${HERE}/nc/
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_09.nc ${mainLink}${year}/${lastAvailDay}/${year}${month}${day}090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc


    ##################################################
    ##  nc -> tiles
    mkdir ${HERE}/tiles/
    cd ${HERE}/nc/
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate}
        
    
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
    backJobs
    
