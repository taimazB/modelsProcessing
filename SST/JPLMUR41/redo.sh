#!/bin/bash
mainLink='https://podaac-opendap.jpl.nasa.gov/opendap/hyrax/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/'
IP='143.110.215.10'

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/SST/JPLMUR41
export archive=/media/taimaz/14TB/SST/JPLMUR41/


##################################################
##  nc -> tiles
mkdir ${HERE}/tiles/
cd ${HERE}/nc/
ls | cut -d_ -f3 | parallel -j 20 "python3 ${HERE}/scripts/cnv.py {}"
    

##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Copy tiles's to server
# rsync -aurq ${HERE}/tiles root@${IP}:/mnt/data/models/SST/JPLMUR41/ &


##################################################
##  Backup
cd ${HERE}
rsync -aurq ${HERE}/tiles ${archive}/ &
