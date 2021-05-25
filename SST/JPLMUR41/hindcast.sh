#!/bin/bash
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst'

############################################################################

HERE=/home/taimaz/Projects/mapBoxData/SST/JPLMUR41

date=$1  ## eg. 2020-08-17
dlDate=`date -d "${date}" +%Y%m%d`


cd ${HERE}/nc/

count=0
while [[ ${count} -lt 12 ]]; do
    ##  longitude order: -180 -> 180
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg01.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(-179.99):1:(-150)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg02.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(-149.99):1:(-120)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg03.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(-119.99):1:(-90)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg04.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(-89.99):1:(-60)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg05.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(-59.99):1:(-30)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg06.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(-29.99):1:(0)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg07.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(0.01):1:(30)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg08.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(30.01):1:(60)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg09.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(60.01):1:(90)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg10.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(90.01):1:(120)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg11.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(120.01):1:(150)]"
    axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg12.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T09:00:00Z):1:(${date}T09:00:00Z)][(-80):1:(80)][(150.01):1:(179.99)]"

    sleep 1
    
    ##  Wait for all downloads to finish
    while [[ `pgrep -c axel` -gt 0 ]]; do
	sleep 1
    done

    count=`ls ${HERE}/nc/JPLMUR41_SST_${dlDate}_reg*.nc | wc -l`
done


##  nc -> png
python3 ${HERE}/scripts/cnv.py ${dlDate}

##  Merge regions
cd ${HERE}/png/
convert +append JPLMUR41_SST_${dlDate}_reg*.png JPLMUR41_SST_${dlDate}_09.png
rm ${HERE}/png/JPLMUR41_SST_${dlDate}_reg*.png

##  png -> jpg (png files are too big for web)
cd ${HERE}/png/
convert -resize 50% ${HERE}/png/JPLMUR41_SST_${dlDate}_09.png ${HERE}/jpg/JPLMUR41_SST_${dlDate}_09.jpg


##################################################
##  Copy jpg's to server
#     ssh taimaz@159.203.6.104 <<EOF
# rm /home/taimaz/web/public/models/HYCOM/UV/jpg/*
# EOF
rsync -aurz ${HERE}/jpg taimaz@159.203.6.104:/home/taimaz/web/public/models/JPLMUR41/SST/
