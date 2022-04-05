import numpy as np
from netCDF4 import Dataset
import sys
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
import os
import imageio
# import tracemalloc
from datetime import datetime, timedelta


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7


fileName = sys.argv[1]
iTime = int(sys.argv[2])  ##  between 0 and 23
iDepth = 0

ncFile = Dataset(fileName,'r')
times = ncFile.variables['time'][:].data ##  minutes since 1900-01-01 00:00:00
u = ncFile.variables['uo'][iTime,iDepth,:,:].data
v = ncFile.variables['vo'][iTime,iDepth,:,:].data
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data
depths = ncFile.variables['depth'][:].data

baseTime = datetime(1900,1,1)
date = (baseTime + timedelta(minutes=int(times[iTime]))).strftime("%Y%m%d_%H")

missingValue = 1e+20
u[u==missingValue] = np.nan
v[v==missingValue] = np.nan


##  Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log( np.tan(np.pi/4 + latNC*np.pi/180/2) )


##  Fixed min/max values for all levels and times
uvMin = -1.5
uvMax = 1.5


##  For interpolation, NaN is not accepted
u[np.isnan(u)] = 0
v[np.isnan(v)] = 0
fu = interpolate.interp2d(xNC, yNC, u, kind='linear')
fv = interpolate.interp2d(xNC, yNC, v, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/CMEMS_Currents_%s/%d/%d' %
                        (date, zoom, i))
    uNew = fu(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    vNew = fv(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    uNew[uNew > uvMax] = uvMax
    uNew[uNew < uvMin] = uvMin
    vNew[vNew > uvMax] = uvMax
    vNew[vNew < uvMin] = uvMin
    #
    # To trim the interpolation tail from the left side
    iLonMin = np.argmin(np.abs(xTile-xMercator(lonNC[0])))
    if(i*tileSize < iLonMin):
        if((i+1)*tileSize < iLonMin):
            uNew[:,:] = 0
            vNew[:,:] = 0
        else:
            uNew[:,:iLonMin % tileSize] = 0
            vNew[:,:iLonMin % tileSize] = 0
    #
    # Normalize
    uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    #
    if(np.min(uNew) == 127 and np.max(uNew) == 127 and np.min(vNew) == 127 and np.max(vNew) == 127):
        return
    else:
        # Coloring
        uvColored = np.empty(
            (uNew.shape[0], uNew.shape[1], 3), dtype=np.uint8)
        uvColored[:, :, 0] = uNew[:, :]
        uvColored[:, :, 1] = vNew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('../tiles/CMEMS_Currents_%s/%d/%d/%d.png' % (date,
                        zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))



def saveTile():
    global zoom, uNew, vNew
    global xTile, yTile
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        iters = np.array(np.meshgrid(np.arange(2**zoom),
                         np.arange(2**zoom))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)



saveTile()
# print(tracemalloc.get_traced_memory())
# tracemalloc.stop()
exit()
