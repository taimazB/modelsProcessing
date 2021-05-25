import numpy as np
from netCDF4 import Dataset
from geojson import Point, Feature, FeatureCollection, dump
import math
from scipy import interpolate
import geojsoncontour
import matplotlib.pyplot as plt
import sys


fileName = sys.argv[1]
indx = int(sys.argv[2])
ncFile = Dataset(fileName,'r')

lon = np.array(ncFile.variables['longitude'])
lat = np.array(ncFile.variables['latitude'])
u = np.array(ncFile.variables['u'])
v = np.array(ncFile.variables['v'])

u[u==1e+20] = np.nan
v[v==1e+20] = np.nan


##  Subarray
sub = 2
lon = lon[::sub, ::sub]
lat = lat[::sub, ::sub]
u = u[::sub, ::sub]
v = v[::sub, ::sub]

gridSize = lon.shape


######################  Point  ######################
features = []
# ss = []
for i in np.arange(gridSize[0]):
    for j in np.arange(0,gridSize[1]):
        if (not np.isnan(u[i,j])):
            speed = math.sqrt(u[i,j]**2+v[i,j]**2)
            # ss.append(speed)
            direction = math.atan2(u[i,j], v[i,j])*180/math.pi
            
            point = Point((1*lon[i,j], 1*lat[i,j]))
            
            features.append(Feature(geometry=point,
                                    properties={"speed": speed,
                                                "direction": direction}
        ))

featureCollection = FeatureCollection(features)
            
with open("riops_forecast_%02d.geojson" % indx, 'w') as f:
    dump(featureCollection, f)
