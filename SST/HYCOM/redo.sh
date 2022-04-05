#!/bin/bash
ftpLink='https://ncss.hycom.org/thredds/ncss/GLBy0.08/expt_93.0/FMRC/runs/'
IP='143.110.215.10'

############################################################################

export HERE=${HOME}/Projects/OceanGNS/data/SST/HYCOM
export archive=/media/taimaz/14TB/SST/HYCOM

    
#########################
##  nc -> tiles
mkdir ${HERE}/tiles/
cd ${HERE}/nc/
ls *_west.nc | sed 's/HYCOM_SST_\(.*\)_west\.nc/\1/' | parallel -j 20 'python3 ${HERE}/scripts/cnv.py {}'


##################################################
##  Remove empty tile directories
cd ${HERE}/tiles/
find . -type d -empty -delete


##################################################
##  Copy tiles's to server
# rsync -aurq ${HERE}/tiles root@${IP}:/mnt/data/models/SST/HYCOM/ &


##################################################
##  Backup tiles
cd ${HERE}
rsync -aurq ${HERE}/tiles ${archive}/ &
