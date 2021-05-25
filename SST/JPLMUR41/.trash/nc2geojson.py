import numpy as np
from netCDF4 import Dataset
import geojsoncontour
import matplotlib.pyplot as plt
import sys
from datetime import datetime, timedelta
from scipy import interpolate


sstMin = -2
sstMax = 35

fileName = "JPLMUR41_SST_20210417_09.nc"
ncFile = Dataset(fileName,'r')
lon = np.array(ncFile.variables['lon'])
lat = np.array(ncFile.variables['lat'])
sst = np.array(ncFile.variables['analysed_sst'][0])
sst -= 273.15
sst[sst<-2] = -2


######################  INTERPOLATE  ######################
xx = np.arange(-180,180,.1)  ## 0.1 deg
yy = np.arange(-80,80,.1)  ## 0.1 deg

f = interpolate.interp2d(lon, lat, sst, kind='linear')
sstNew = f(xx, yy)

subSST = sstNew[:800,:1800]
subXX = xx[:1800]
subYY = yy[:800]

######################  Contour  ######################
figure = plt.figure()
ax = figure.add_subplot(111)
colorRange = np.arange(sstMin,sstMax,.1)
contour = ax.contour(subXX, subYY, subSST, levels=colorRange, vmin=0, vmax=7)
contour = ax.contour(xx, yy, sstNew, levels=colorRange, vmin=0, vmax=7)
contourf = ax.contourf(lon, lat, sst, levels=colorRange)

# contourf = ax.contourf(lon, lat, sst, levels=np.arange(-2,8,.1), cmap=plt.cm.nipy_spectral)
# contourf = ax.contourf(lon, lat, sst, levels=np.arange(sstMin,sstMax,.1), cmap=plt.cm.prism)
    
#    plt.show()
    
#    exit()
    
geojson = geojsoncontour.contourf_to_geojson(contourf=contourf, ndigits=4, unit="")
    
file1 = open("JPLMUR41_SST_20210417_09.geojson", "w")
file1.write(geojson)
file1.close()



def colorbarText():
    from matplotlib import cm
    for sst in np.arange(sstMin,sstMax,.1):
        color = cm.nipy_spectral(int(np.sqrt((sst-sstMin)/(sstMax-sstMin))*255))
        r = int(255*color[0])
        g = int(255*color[1])
        b = int(255*color[2])
        print("rgb(%d,%d,%d)," % (r,g,b), end='')


gj()
# colorbarText()
