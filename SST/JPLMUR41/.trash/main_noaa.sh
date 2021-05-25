#!/bin/bash
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst'

############################################################################

HERE=/home/taimaz/Projects/mapBoxData/SST/JPLMUR41

# rm ${HERE}/nc/tmp.nc
# dlLink="${ftpLink}[(last)][(0):1:(1)][(0):1:(1)]"
# axel -a -n 50 -o ${HERE}/nc/tmp.nc ${dlLink}
# lastAvailDate=`ncdump -h ${HERE}/nc/tmp.nc | grep time_coverage_start | sed 's/.*time_coverage_start = "// ; s/T.*//'`
# lastAvailDate=`date -d "${lastAvailDate}" +%Y%m%d`
# lastDlDate=`cat ${HERE}/.lastAvailDate`
lastAvailDate=20210401
rm ${HERE}/nc/tmp.nc


if [[ ! -z ${lastAvailDate} ]] &&  [[ ${lastAvailDate} != ${lastDlDate} ]]; then

    cd ${HERE}/nc/

    count=0
    while [[ ${count} -lt 12 ]]; do
	##  longitude order: -180 -> 180
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg01.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(-179.99):1:(-150)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg02.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(-149.99):1:(-120)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg03.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(-119.99):1:(-90)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg04.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(-89.99):1:(-60)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg05.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(-59.99):1:(-30)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg06.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(-29.99):1:(0)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg07.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(0.01):1:(30)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg08.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(30.01):1:(60)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg09.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(60.01):1:(90)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg10.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(90.01):1:(120)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg11.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(120.01):1:(150)]" &
	axel -a -n 50 -o ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg12.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(last)][(-80):1:(80)][(150.01):1:(179.99)]" &
	sleep 1
    
	##  Wait for all downloads to finish
	while [[ `pgrep -c axel` -gt 0 ]]; do
	    sleep 1
	done

	count=`ls ${HERE}/nc/JPLMUR41_SST_${lastAvailDate}_reg*.nc | wc -l`
    done

    
    ##  nc -> png
    cd ${HERE}/nc/
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate}

    ##  Merge regions
    cd ${HERE}/png/
    convert +append JPLMUR41_SST_${lastAvailDate}_reg*.png JPLMUR41_SST_${lastAvailDate}_09.png
    rm ${HERE}/png/JPLMUR41_SST_${lastAvailDate}_reg*.png
    
    ##  png -> jpg (png files are too big for web)
    cd ${HERE}/png/
    convert ${HERE}/png/JPLMUR41_SST_${lastAvailDate}_09.png ${HERE}/jpg/highRes/JPLMUR41_SST_${lastAvailDate}_09.jpg
    convert -resize 10% ${HERE}/png/JPLMUR41_SST_${lastAvailDate}_09.png ${HERE}/jpg/lowRes/JPLMUR41_SST_${lastAvailDate}_09.jpg

    
    ##################################################
    ##  Copy jpg's to server
#     ssh taimaz@159.203.6.104 <<EOF
# rm /home/taimaz/web/public/models/HYCOM/UV/jpg/*
# EOF
    # rsync -aurz ${HERE}/jpg taimaz@159.203.6.104:/mnt/external/models/SST/JPLMUR41/

    echo ${lastAvailDate} > ${HERE}/.lastAvailDate
    
fi
