#!/bin/bash

export HERE=${HOME}/Projects/OceanGNS/data/Currents/HYCOM
export archive=/media/taimaz/14TB/Currents/HYCOM

lastAvailDate=$1

mkdir ${HERE}/nc/
mkdir ${HERE}/png/
mkdir -p ${HERE}/jpg/highRes ${HERE}/jpg/lowRes
    

cd ${HERE}/nc
# ln -s ${archive}/nc/HYCOM_Currents_${lastAvailDate}_*_west.nc .
# ln -s ${archive}/nc/HYCOM_Currents_${lastAvailDate}_*_east.nc .

    
#########################
##  Average depth
cd ${HERE}/nc/
ls HYCOM_Currents_${lastAvailDate}*_west.nc | sed 's/HYCOM_Currents_\(.*\)_west\.nc/\1/' | parallel -j 2 'python3 ${HERE}/scripts/cnv.py {}'

    
##################################################
##  Convert png to jpg  (png's are too big)
cd ${HERE}/png/
ls *.png | parallel 'convert {} ../jpg/highRes/`basename {} .png`.jpg'
ls *.png | parallel 'convert -resize 30% {} ../jpg/lowRes/`basename {} .png`.jpg'
rm -r ${HERE}/png/
    
cd ${HERE}/jpg/highRes/
for f in HYCOM_Currents_*.jpg; do
    dir=`echo $f | cut -d_ -f1-4`
    mkdir ${dir} 2>/dev/null
    mv ${dir}*.jpg ${dir} 2>/dev/null
done

cd ${HERE}/jpg/lowRes/
for f in HYCOM_Currents_*.jpg; do
    dir=`echo $f | cut -d_ -f1-4`
    mkdir ${dir} 2>/dev/null
    mv ${dir}*.jpg ${dir} 2>/dev/null
done
    
    
##################################################
##  Copy jpg's to server
rsync -aur ${HERE}/jpg taimaz@159.203.6.104:/mnt/data/models/Currents/HYCOM/


##################################################
##  Backup jpg's
cd ${HERE}
rsync -aur ${HERE}/jpg/highRes ${archive}/jpg/
rsync -aur ${HERE}/jpg/lowRes ${archive}/jpg/
rm -r ${HERE}/jpg/
    
    
mv ${HERE}/nc/HYCOM_Currents_avgDepth_${lastAvailDate}*.nc ${archive}/hindcast/

cd ${HERE}
# rm -r ${HERE}/nc
