import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
from datetime import datetime, timedelta


date = sys.argv[1]
hr = int(sys.argv[2])

dateSave = datetime.strptime(date, "%Y%m%d")
hrSave = hr
while(hrSave>=24):
    dateSave += timedelta(days=1)
    hrSave -= 24


ncFile = Dataset("CMC_rdwps_gulf-st-lawrence_HTSGW_SFC_0_latlon0.05x0.05_%s00_P%03d.nc" % (date, hr), 'r')

## Significant height of combined wind waves and swell
swh = ncFile.variables['swh'][0].data
# lat = ncFile.variables['lat'][:].data
# lon = ncFile.variables['lon'][:].data

swhMin = 0.
swhMax = 30.

swh[swh<0] = swhMin  ##  For interpolation, NaN is not accepted

##  latitude and longitude
##  nc files are already from lat: 80S to 80N
lat = np.arange(-80,80.01,0.25)
lon = np.arange(0,360,0.25)
swh = swh[40:681]  ##  Limit lat range


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), lon.shape[0])  ## 0.01 deg
yy = np.linspace(np.min(y), np.max(y), lat.shape[0])  ## 0.01 deg


f = interpolate.interp2d(x, y, swh, kind='linear')
swhNew = f(xx, yy)

##  Rearrange u and v to lon: -180 to 180
swhNew = np.concatenate((swhNew[:,int(len(lon)/2):], swhNew[:,:int(len(lon)/2)]), axis=1)


img = np.empty(swhNew.shape, dtype=np.uint16)
img[:,:] = 2**16*(swhNew-swhMin)/(swhMax-swhMin)

with open('../png/CMC-GOSL_SWH_%s_%02d.png' % (datetime.strftime(dateSave, "%Y%m%d"), hrSave), 'wb') as f:
    writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=True)
    # Convert img to the Python list of lists expected by the png writer
    img2list = np.flipud(img).reshape(-1, img.shape[1]).tolist()
    writer.write(f, img2list)


# plt.imshow(sstNew)
# plt.show()
