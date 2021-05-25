import numpy as np
from netCDF4 import Dataset
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing


date = sys.argv[1]

# list = []
for reg in np.arange(1,13):
    # reg = 1
    print(reg)
    ncFile = Dataset("JPLMUR41_SST_%s_reg%02d.nc" % (date, reg), 'r')
    # list.append(ncFile.variables['analysed_sst'][0].data)

    # sst = np.concatenate(list, axis=1)
    sst = ncFile.variables['analysed_sst'][0].data
    lat = ncFile.variables['latitude'][:].data
    lon = ncFile.variables['longitude'][:].data
    sstMin = -2.
    sstMax = 35.

    sst[sst<-2] = sstMin  ##  For interpolation, NaN is not accepted

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
    xx = np.linspace(np.min(x), np.max(x), lon.shape[0])  ## 0.01 deg
    yy = np.linspace(np.min(y), np.max(y), lat.shape[0])  ## 0.01 deg


    f = interpolate.interp2d(x, y, sst, kind='linear')
    
    sstNew = f(xx, yy)
    
    img = np.empty(sstNew.shape, dtype=np.uint16)
    
    img[:,:] = 2**16*(sstNew-sstMin)/(sstMax-sstMin)
    
    with open('../png/JPLMUR41_SST_%s_reg%02d.png' % (date, reg), 'wb') as f:
        writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=True)
        # Convert img to the Python list of lists expected by the png writer
        img2list = np.flipud(img).reshape(-1, img.shape[1]).tolist()
        writer.write(f, img2list)


    # plt.imshow(sstNew)
    # plt.show()
