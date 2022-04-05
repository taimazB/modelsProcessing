import numpy as np
from netCDF4 import Dataset
from geojson import Point, Feature, FeatureCollection, dump
import math
from scipy import interpolate
import geojsoncontour
import matplotlib.pyplot as plt


fileName = "uv_avgDepth_avgTime_forecast"
ncFile = Dataset("nc/"+fileName+".nc",'r')

lon = np.array(ncFile.variables['longitude'])
lat = np.array(ncFile.variables['latitude'])
u = np.array(ncFile.variables['u'])
v = np.array(ncFile.variables['v'])


lon[lon>180] = lon[lon>180]-360

##  Subarray
sub = 3
lon = lon[::sub]
lat = lat[::sub]
u = u[::sub, ::sub]
v = v[::sub, ::sub]

m=0
######################  Point  ######################
features = []
for i in np.arange(0,lon.shape[0]):
    if lon[i]>-70 and lon[i]<-10:
        print(lon[i])
        for j in np.arange(0,lat.shape[0]):
            if lat[j]>40 and lat[j]<80:
                if (not np.isnan(u[j,i])):
                    speed = math.sqrt(u[j,i]**2+v[j,i]**2)
                    if speed>m:
                        m=speed
                    direction = math.atan2(u[j,i], v[j,i])*180/math.pi

                    point = Point((lon[i], lat[j]))

                    features.append(Feature(geometry=point,
                                            properties={"speed": speed,
                                                        "direction": direction}
                    ))

featureCollection = FeatureCollection(features)

with open("gj/%s_point.geojson" % fileName, 'w') as f:
   dump(featureCollection, f)

   
exit()   
######################  Contour  ######################
speed = np.sqrt(np.power(u,2)+np.power(v,2))
lonGrid, latGrid = np.meshgrid(np.linspace(-180,180,lon.shape[0]), np.linspace(-80,90,lat.shape[0]))

##  Interpolate over NANs
speed = np.ma.masked_invalid(speed)
lonGrid1D = lonGrid[~speed.mask]
latGrid1D = latGrid[~speed.mask]

speedNoNAN = speed[~speed.mask]
speedInterpolate = interpolate.griddata((lonGrid1D, latGrid1D), speedNoNAN.ravel(), (lonGrid, latGrid), method = 'cubic')


##  Create contour
figure = plt.figure()
ax = figure.add_subplot(111)
# contourf = ax.contourf(lon_range, lat_range, Z, np.arange(-2,35,1), cmap=plt.cm.jet, extend='neither')
contourf = ax.contourf(lonGrid, latGrid, speedInterpolate, np.arange(0,3,.1), cmap=plt.cm.jet, extend='neither')
# contour = ax.contour(lon_range, lat_range, Z, cmap=plt.cm.jet)

# plt.show()


geojsonf = geojsoncontour.contourf_to_geojson(contourf=contourf, ndigits=0, unit='m/s')
# geojson = geojsoncontour.contour_to_geojson(contour=contour, ndigits=3, unit='m/s')

file1 = open("gj/%s_contourf.geojson" % fileName, "w")
file1.write(geojsonf)
file1.close()

