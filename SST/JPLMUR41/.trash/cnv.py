import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing


date = sys.argv[1]

ncFile = Dataset("JPLMUR41_SST_%s.nc" % date, 'r')
sst = ncFile.variables['analysed_sst'][0].data
# lat = ncFile.variables['lat'][:].data
lat = np.arange(-80,80,0.01)
lon = ncFile.variables['lon'][:].data
sstMin = -2.
sstMax = 35.


sst = sst[1000:-999,:]  ##  lat: 80S - 80N
sst -= 273.15
sst[sst<sstMin] = sstMin  ##  For interpolation, NaN is not accepted


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), lon.shape[0])  ## 0.01 deg
yy = np.linspace(np.min(y), np.max(y), lat.shape[0])  ## 0.01 deg


f = interpolate.interp2d(x, y, sst, kind='linear')
    
sstNew = f(xx, yy)
    
img = np.empty(sstNew.shape, dtype=np.uint16)
    
img[:,:] = 2**16*(sstNew-sstMin)/(sstMax-sstMin)
    
with open('../png/JPLMUR41_SST_%s_09.png' % date, 'wb') as f:
    writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=True)
    # Convert img to the Python list of lists expected by the png writer
    img2list = np.flipud(img).reshape(-1, img.shape[1]).tolist()
    writer.write(f, img2list)


# plt.imshow(sstNew)
# plt.show()
