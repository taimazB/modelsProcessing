#!/bin/bash
ftpLink='https://coastwatch.pfeg.noaa.gov/erddap/griddap/nesdisVHNnoaa20chlaWeekly.nc?chlor_a'

############################################################################

HERE=/home/taimaz/Projects/mapBoxData/chlorophyll
log=${HOME}/Projects/mapBoxData/log/fields.log


##  Get latest csv from server
# scp taimaz@138.197.153.60:/home/taimaz/node/public/pearlDiver/csv/pd_txy_email.csv ${HERE}/pd.csv

latMin=40
latMax=75
lonMin=-80
lonMax=0


rm ${HERE}/nc/chlorophyll_nesdis.nc
dlLink="${ftpLink}[(last)][(0.0):1:(0.0)][(${latMax}):1:(${latMin})][(${lonMin}):1:(${lonMax})]"
axel -a -n 50 -o ${HERE}/nc/chlorophyll_nesdis.nc ${dlLink}
lastAvailDate=`ncdump -h ${HERE}/nc/chlorophyll_nesdis.nc | grep time_coverage_start | sed 's/.*time_coverage_start = "// ; s/T.*//'`
lastDlDate=`cat lastDlDate.txt`
rm ${HERE}/nc/chlorophyll_nesdis.nc

    
if [[ ${lastAvailDate} == ${lastDlDate} ]]; then
    echo -e "##  Chlorophyll:\tNo new file available yet @ `date`" >> ${log}
else
    ##  Downloading last 7 available dates
    c=1
    i=0
    while [[ $c -le 7 ]]; do
	date=`date -d "${lastAvailDate} -$i day" +%F`
	if [[ ! -e ${HERE}/nc/chlorophyll_nesdis_${date}.nc ]]; then

	    ##  Download
	    dlLink="${ftpLink}[(${date}T12:00:00Z):1:(${date}T12:00:00Z)][(0.0):1:(0.0)][(${latMax}):1:(${latMin})][(${lonMin}):1:(${lonMax})]"
	    axel -a -n 50 -o ${HERE}/nc/chlorophyll_nesdis_${date}.nc ${dlLink}
	    if [[ $? -eq 0 ]]; then
		c=$((c+1))

		
		##  Convert to GeoJson
		cd ${HERE}
		python3 ${HERE}/scripts/nc2geojson.py ${date}
		sed -i 's/"fill-opacity":0\.9,"stroke":"#......","stroke-opacity":1,"stroke-width":1,//g ; s/\.00 //g' ${HERE}/gj/chlorophyll_nesdis_${date}_contourf.geojson

	    
		##  Upload and publish on mapbox
		cd ${HERE}/gj
		bash ${HERE}/scripts/addTileset.sh chlorophyll_nesdis ${date}
	    fi
	else
	    echo "##  chlorophyll_nesdis_${date}.nc already present."
	    c=$((c+1))
	fi
	i=$((i+1))
    done

    
    ##  List available dates for historical plotting
    cd ${HERE}
    echo "Date" > ${HERE}/chlorophyll_nesdis_availDates.txt
    ls ${HERE}/gj/chlorophyll_nesdis_*_contourf.geojson | tail -7 | sed "s/.*chlorophyll_nesdis_\(.*\)_contourf.*/\1/" >> ${HERE}/chlorophyll_nesdis_availDates.txt
    echo -e "##  chlorophyll:\tUpdated @ `date`" >> ${log}

    echo "chlorophyll,`date +%FT%T`" >> ${HERE}/../lastUpdated.dat
    scp ${HERE}/../lastUpdated.dat taimaz@159.203.6.104:/home/taimaz/web/public/
    scp ${HERE}/chlorophyll_nesdis_availDates.txt taimaz@159.203.6.104:/home/taimaz/web/public/layers
fi
