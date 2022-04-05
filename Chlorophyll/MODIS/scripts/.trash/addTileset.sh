export MAPBOX_ACCESS_TOKEN="sk.eyJ1IjoidGFpbWF6IiwiYSI6ImNrN2dscDd3OTAweXozZGthdHc2aGZuM2gifQ.qLA2cvzcu-ykOyh0G9opBQ"
tilesets=${HOME}/.local/bin/tilesets


fileName=$1
date=$2

##  Create recipe
cat <<EOF > ../scripts/${fileName}_${date}_recipe.json
{
  "version": 1,
  "layers": {
    "${fileName}_${date}": {
      "source": "mapbox://tileset-source/taimaz/${fileName}_${date}",
      "minzoom": 0,
      "maxzoom": 10
    }
  }
}
EOF


##  Delete current data source
echo y | ${tilesets} delete-source taimaz ${fileName}_${date}

##  Create a tileset source
${tilesets} add-source taimaz ${fileName}_${date} ${fileName}_${date}_contourf.geojson

##  Create a new tileset (Only for first time creation of the tileset)
${tilesets} create taimaz.${fileName}_${date} --recipe ../scripts/${fileName}_${date}_recipe.json --name "${fileName}_${date}"

##  Publish the new tileset
${tilesets} publish taimaz.${fileName}_${date}


##  Don't submit all at once -> "Too Many Requests" error
# sleep 60
