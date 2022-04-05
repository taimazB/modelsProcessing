#!/bin/bash
ftpLink='https://oceandata.sci.gsfc.nasa.gov/opendap/MODISA/L3SMI/'

############################################################################

export HERE=${HOME}/Projects/data/Chlorophyll/MODIS

cd ${HERE}/nc
for DOY in {2..55}; do
    DOY3=`printf %03d ${DOY}`
    year=2022
    
    dlLink="${ftpLink}${year}/${DOY3}/A${year}${DOY3}.L3m_DAY_CHL_chlor_a_4km.nc.nc4?'"
    date=`date -d "${year}0101 +$((DOY-1)) days" +%Y%m%d`
    wget -O ${HERE}/nc/MODIS_Chlorophyll_${date}.nc ${dlLink}
done
