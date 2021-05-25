import numpy as np
from netCDF4 import Dataset
from geojson import Point, Feature, FeatureCollection, dump
import math
from scipy import interpolate
import geojsoncontour
import matplotlib.pyplot as plt
import sys


date = sys.argv[1]
indx = int(sys.argv[2])
fileName = "uv_avgDepth_%s.nc" % date
ncFile = Dataset(fileName,'r')

lon = np.array(ncFile.variables['longitude'])
lat = np.array(ncFile.variables['latitude'])
u = np.array(ncFile.variables['u'])
v = np.array(ncFile.variables['v'])

lon[lon>180] -= 360


##  Subarray
sub = 2
lon = lon[::sub]
lat = lat[::sub]
u = u[::sub, ::sub]
v = v[::sub, ::sub]


######################  Point  ######################
features = []
# ss = []
for i in np.arange(lat.shape[0]):
    for j in np.arange(lon.shape[0]):
        # if lat[i]>40 and lat[i]<80 and lon[j]>-70 and lon[j]<-10:
            if (not np.isnan(u[i,j])):
                speed = math.sqrt(u[i,j]**2+v[i,j]**2)
                # ss.append(speed)
                direction = math.atan2(u[i,j], v[i,j])*180/math.pi
                    
                point = Point((1*lon[j], 1*lat[i]))
                    
                features.append(Feature(geometry=point,
                                        properties={"speed": speed,
                                                    "direction": direction}
                ))

featureCollection = FeatureCollection(features)

with open("hycom_forecast_%02d.geojson" % indx, 'w') as f:
    dump(featureCollection, f)
