import numpy as np
from netCDF4 import Dataset
from geojson import Point, Feature, FeatureCollection, dump
import math
from scipy import interpolate
import geojsoncontour
import matplotlib.pyplot as plt
import matplotlib.colors
import sys


date = sys.argv[1]
fileName = "chlorophyll_nesdis_" + date
ncFile = Dataset("nc/"+fileName+".nc",'r')
lon = np.array(ncFile.variables['longitude'])
lat = np.array(ncFile.variables['latitude'])
chlr = np.array(ncFile.variables['chlor_a'][0,0])


######################  Contour  ######################
figure = plt.figure()
ax = figure.add_subplot(111)
cmap = matplotlib.colors.LinearSegmentedColormap.from_list("", ["blue","green","red"])
# levels=[0,.1,.2,.3,.4,.5,.6,.7,.8,.9,1,2,3,4,5,6,7,8,9,10,20,30,40,50,60,70,80,90,100,200,300,400]
# levels=[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1,2,3,4,5,6,7,8,9,10]
# levels = [0,.1,.2,.3,.4,.5,.6,.7,.8,.9,1]
# levels = [0.01,0.1,1,10,100,1000]
levels = [0.01,0.02,0.03,0.05,0.1,0.2,0.3,0.5,1,2,3,5,10,20,30,50,100,1000]

# contourf = ax.contourf(lon, lat, chlr, levels=levels, cmap=plt.cm.nipy_spectral, norm=matplotlib.colors.LogNorm())
# contourf = ax.contourf(lon, lat, chlr, levels=levels, cmap=plt.cm.nipy_spectral)
contourf = ax.contourf(lon, lat, chlr, levels=levels, cmap=plt.cm.nipy_spectral, norm=matplotlib.colors.LogNorm())
    
# plt.colorbar(contourf)
# plt.savefig("10-100.jpg", dpi=1000)
# plt.show()

# exit()

geojsonf = geojsoncontour.contourf_to_geojson(contourf=contourf, ndigits=0, unit="")


file1 = open("gj/%s_contourf.geojson" % fileName, "w")
file1.write(geojsonf)
file1.close()
