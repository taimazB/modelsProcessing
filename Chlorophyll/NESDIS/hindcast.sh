#!/bin/bash
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/nesdisVHNnoaa20chlaDaily.nc?chlor_a'

############################################################################

HERE=/home/taimaz/Projects/mapBoxData/Chlorophyll/NESDIS/

date=$1 ##  eg 2020-12-17
dlDate=`date -d "${date}" +%Y%m%d`


cd ${HERE}/nc/
dlLink="${ftpLink}[(${date}):1:(${date})][(0.0):1:(0.0)][(80):1:(-80)][(-179.99):1:(179.99)]"
axel -a -n 50 -o ${HERE}/nc/NESDIS_Chlorophyll_${dlDate}_12.nc ${dlLink}

##  nc -> png
python3 ${HERE}/scripts/cnv.py ${dlDate}

   
##  png -> jpg
cd ${HERE}/png/
convert ${HERE}/png/NESDIS_Chlorophyll_${dlDate}_12.png ${HERE}/jpg/NESDIS_Chlorophyll_${dlDate}_12.jpg

    
##################################################
##  Copy jpg's to server
#     ssh taimaz@159.203.6.104 <<EOF
# rm /home/taimaz/web/public/models/NESDIS/Chlorophyll/jpg/*
# EOF
rsync -aurz ${HERE}/jpg taimaz@159.203.6.104:/home/taimaz/web/public/models/NESDIS/Chlorophyll/
