export MAPBOX_ACCESS_TOKEN="sk.eyJ1Ijoib2NlYW5nbnMiLCJhIjoiY2tvcjc2aTl0MG1yMDJvbGw2cXlhdDBpZyJ9.Yv11rNZW352kU9o14nYi4w"
export tilesets=/home/taimaz/.local/bin/tilesets


##  Create a tileset source
for m in {1..12}; do
    sed "s/iceberg/iceberg_m${m}/" ../scripts/iceberg.json > ../scripts/iceberg_m${m}.json

    ##  Delete current data source
    echo y | tilesets delete-source oceangns iceberg_m${m}
    tilesets add-source oceangns iceberg_m${m} seaice_m${m}.geojson

    sleep 15
done

##  Create a new tileset (Only for first time creation of the tileset)
tilesets create oceangns.iceberg --recipe iceberg.json --name "iceberg"

##  Publish the new tileset
tilesets publish oceangns.iceberg
