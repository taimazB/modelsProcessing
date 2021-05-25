import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing


date = sys.argv[1] ## eg 20201217

ncFile = Dataset("NESDIS_Chlorophyll_%s_12.nc" % date, 'r')

chlr = ncFile.variables['chlor_a'][0,0].data
lat = ncFile.variables['latitude'][:].data
lon = ncFile.variables['longitude'][:].data
chlrMin = -3 ## log(0.001)
chlrMax = 3 ## log(1000.)

chlr[np.isnan(chlr)] = 0  ##  For interpolation, NaN is not accepted

##  latitude and longitude
##  nc files are already from lat: 80S to 80N
# lat = np.arange(-80,80.01,0.01)
# lon = np.arange(0,359.99,0.01)


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
# xx = np.linspace(np.min(x), np.max(x), 35999)  ## 0.01 deg
# yy = np.linspace(np.min(y), np.max(y), 16001)  ## 0.01 deg
xx = np.linspace(np.min(x), np.max(x), lon.shape[0])  ## 0.02 deg
yy = np.linspace(np.min(y), np.max(y), lat.shape[0])  ## 0.02 deg


f = interpolate.interp2d(x, y, chlr, kind='linear')
    
chlrNew = f(xx, yy)
    
img = np.empty(chlrNew.shape, dtype=np.uint16)
    
img[:,:] = 2**16*(np.log10(chlrNew)-chlrMin)/(chlrMax-chlrMin)
    
with open('../png/NESDIS_Chlorophyll_%s_12.png' % date, 'wb') as f:
    writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=True)
    # Convert img to the Python list of lists expected by the png writer
    img2list = np.flipud(img).reshape(-1, img.shape[1]).tolist()
    writer.write(f, img2list)


# plt.imshow(sstNew)
# plt.show()
