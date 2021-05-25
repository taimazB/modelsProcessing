#!/bin/bash

export HERE=${HOME}/Projects/OceanGNS/data/Currents/RIOPS
export archive=/media/taimaz/14TB/Currents/RIOPS

export lastAvailDate=$1


############################################################################
##  FUNCTIONS


function dl {
    hr=$1
    echo "##  ${lastAvailDate}_${hr}"
    tar -xzf ${archive}/nc/CMC_RIOPS_ux_${lastAvailDate}_${hr}.nc.tar.gz
    tar -xzf ${archive}/nc/CMC_RIOPS_vy_${lastAvailDate}_${hr}.nc.tar.gz
}
export -f dl


function py {
    hr=$1
    ##  (uxmvy) -> (u,v); save jpg; average depth
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate} ${hr}
}
export -f py


##  FUNCTIONS
############################################################################

mkdir ${HERE}/nc/
mkdir ${HERE}/png/
mkdir ${HERE}/jpg/

cd ${HERE}/nc/

echo -e "\tDownloading ..." ; parallel -j 8 "dl {}" ::: {000..021..3}
echo -e "\tProcessing ..." ; parallel -j 4 "py {}" ::: {000..021..3}  ## depth averaging and image saving


##################################################
##  Convert png to jpg  (png's are big)
echo -e "\tpng to jpg ..."
cd ${HERE}/png/
ls *.png | parallel 'convert {} ../jpg/`basename {} .png`.jpg'
rm -r ${HERE}/png/

cd ${HERE}/jpg/
for f in RIOPS_Currents_*.jpg; do
    dir=`echo $f | cut -d_ -f1-4`
    mkdir ${dir}
    mv ${dir}*.jpg ${dir}
done


##################################################
##  Copy jpg's to server
rsync -aur ${HERE}/jpg taimaz@159.203.6.104:/mnt/data/models/Currents/RIOPS/


##################################################
##  Backup jpg's
rsync -aur ${HERE}/jpg ${archive}
rm -r ${HERE}/jpg/


##################################################
##  Path Planning time averaged & 8 time steps forecast files
cd ${HERE}/nc/
cp ${HERE}/nc/RIOPS_Currents_avgDepth_${lastAvailDate}_*.nc ${archive}/hindcast/

rm -r ${HERE}/nc/
