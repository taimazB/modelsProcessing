from geojson import Point, Feature, FeatureCollection, dump
import geojsoncontour
import pandas as pd


fileName = "seaice"
csvFile = pd.read_csv("csv/"+fileName+".csv")


######################  Point  ######################
for month in range(1,13):
    features = []
    print(month)
    lons = csvFile[csvFile['SIGHTING_DATE'].str.startswith(str(month)+'/', na=False)]['SIGHTING_LONGITUDE']
    lats = csvFile[csvFile['SIGHTING_DATE'].str.startswith(str(month)+'/', na=False)]['SIGHTING_LATITUDE']

    for lon,lat in zip(lons,lats):
        point = Point((float(lon), float(lat)))
        features.append(Feature(geometry=point,
                                properties={"month": month}
        ))

    featureCollection = FeatureCollection(features)

    with open("gj/seaice_m"+str(month)+".geojson", 'w') as f:
        dump(featureCollection, f)
