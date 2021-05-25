export MAPBOX_ACCESS_TOKEN="sk.eyJ1IjoidGFpbWF6IiwiYSI6ImNrN2dscDd3OTAweXozZGthdHc2aGZuM2gifQ.qLA2cvzcu-ykOyh0G9opBQ"
tilesets=${HOME}/.local/bin/tilesets


##  Delete current data source
echo y | ${tilesets} delete-source taimaz riopsUV_point

##  Create a tileset source
${tilesets} add-source taimaz riopsUV_point uv_avgDepth_avgTime_forecast_point.geojson

##  Create a new tileset (Only for first time creation of the tileset)
# tilesets create taimaz.riopsUV_point --recipe scripts/riopsUVpoint_recipe.json --name "riopsUV_point"

##  Publish the new tileset
${tilesets} publish taimaz.riopsUV_point
