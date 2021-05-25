export MAPBOX_ACCESS_TOKEN="sk.eyJ1IjoidGFpbWF6IiwiYSI6ImNrN2dscDd3OTAweXozZGthdHc2aGZuM2gifQ.qLA2cvzcu-ykOyh0G9opBQ"
tilesets=${HOME}/.local/bin/tilesets

I=$1

##  Create recipe
cat <<EOF > ../scripts/riops_forecast_${I}_recipe.json
{
  "version": 1,
  "layers": {
    "riops_forecast_${I}": {
      "source": "mapbox://tileset-source/taimaz/riops_forecast_${I}",
      "minzoom": 0,
      "maxzoom": 10
    }
  }
}
EOF


##  Delete current data source
echo y | ${tilesets} delete-source taimaz riops_forecast_${I}

##  Create a tileset source
${tilesets} add-source taimaz riops_forecast_${I} riops_forecast_${I}.geojson

##  Create a new tileset (Only for first time creation of the tileset)
${tilesets} create taimaz.riops_forecast_${I} --recipe ../scripts/riops_forecast_${I}_recipe.json --name "riops_forecast_${I}"

##  Publish the new tileset
${tilesets} publish taimaz.riops_forecast_${I}
