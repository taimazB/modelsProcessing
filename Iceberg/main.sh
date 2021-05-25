ftpLink="ftp://sidads.colorado.edu/pub/DATASETS/NOAA/G00807"

HERE=/home/taimaz/Projects/mapBoxData/iceberg


for year in {2002..2019}; do
    dlLink=${ftpLink}/IIP_${year}IcebergSeason.csv
    axel -o ${HERE}/csv ${dlLink}
done


cd ${HERE}/csv
head -1 IIP_2019IcebergSeason.csv > seaice.csv
for f in IIP_*.csv; do
    sed '1d' $f >> seaice.csv
done


cd ${HERE}
python3 ${HERE}/scripts/nc2geojson.py


##  Upload and publish on mapbox
cd ${HERE}/gj
bash ${HERE}/scripts/addTileset.sh
