ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst'

############################################################################

HERE=/home/taimaz/Projects/mapBoxData/sst/jplMUR41

for d in {01..11}; do
    lastAvailDate=202011${d}
    date=2020-11-${d}

        cd ${HERE}/nc/

    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg01.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(-179.99):1:(-150)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg02.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(-149.99):1:(-120)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg03.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(-119.99):1:(-90)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg04.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(-89.99):1:(-60)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg05.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(-59.99):1:(-30)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg06.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(-29.99):1:(0)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg07.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(0.01):1:(30)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg08.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(30.01):1:(60)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg09.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(60.01):1:(90)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg10.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(90.01):1:(120)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg11.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(120.01):1:(150)]" &
    axel -a -n 50 -o ${HERE}/nc/JPLMUN41_SST_${lastAvailDate}_reg12.nc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.nc?analysed_sst[(${date}T12:00:00):1:(${date}T12:00:00)][(-80):1:(80)][(150.01):1:(179.99)]" &


    ##  Wait for all downloads to finish
    while [[ `pgrep -c axel` -gt 0 ]]; do
	sleep 1
    done

    
    ##  nc -> png
    python3 ${HERE}/scripts/cnv.py ${lastAvailDate}

    ##  Merge regions
    cd ${HERE}/png/
    convert +append JPLMUR41_SST_${lastAvailDate}_reg*.png JPLMUR41_SST_${lastAvailDate}.png
    rm ${HERE}/png/JPLMUR41_SST_${lastAvailDate}_reg*.png
    
    ##  png -> jpg (png files are too big for web)
    cd ${HERE}/png/
    convert -resize 50% ${HERE}/png/JPLMUR41_SST_${lastAvailDate}.png ${HERE}/jpg/JPLMUR41_SST_${lastAvailDate}.jpg
done
