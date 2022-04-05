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
import math


field = 'Currents'
model = 'Barents'

maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7

# tracemalloc.start()
date = sys.argv[1]
depth = sys.argv[2]


nc = Dataset("%s_%s_%s_%s_regrid.nc" % (field, model, date, depth), 'r')
u = nc.variables['u'][:].data
v = nc.variables['v'][:].data
times = nc.variables['time'][:].data
missingValue = nc['u'].missing_value

u[u == missingValue] = np.nan
v[v == missingValue] = np.nan

# Depth average
uz = np.nanmean(u, axis=1)
vz = np.nanmean(v, axis=1)


##  latitude, longitude, depth
lonNC = nc.variables['lon'][:].data
latNC = nc.variables['lat'][:].data


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
uvMin = -1
uvMax = 1


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    try:
        if(yTile[j*tileSize: (j+1)*tileSize].min() > yNC.max() or
           yTile[j*tileSize: (j+1)*tileSize].max() < yNC.min()):
            return
    except:
        return
    devNull = os.system('mkdir -p ../tiles/%s_%s_%s_%s/%d/%d' %
                        (model, field, dateTimeSave, depth, zoom, i))
    uNew = fu(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    vNew = fv(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    uNew[uNew > uvMax] = uvMax
    uNew[uNew < uvMin] = uvMin
    vNew[vNew > uvMax] = uvMax
    vNew[vNew < uvMin] = uvMin
    #
    # To trim the interpolation tail from the right side
    iLonMax = np.argmin(np.abs(xTile-xMercator(lonNC[-1])))
    if((i+1)*tileSize > iLonMax):
        if(i*tileSize > iLonMax):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[:, iLonMax % tileSize:] = 0
            vNew[:, iLonMax % tileSize:] = 0
    #
    # To trim the interpolation tail from the left side
    iLonMin = np.argmin(np.abs(xTile-xMercator(lonNC[0])))
    if(i*tileSize < iLonMin):
        if((i+1)*tileSize < iLonMin):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[:, :iLonMin % tileSize] = 0
            vNew[:, :iLonMin % tileSize] = 0
    #
    # To trim the interpolation tail from the top side
    jLatMax = np.argmin(np.abs(yTile-yMercator(latNC[-1])))
    if((j+1)*tileSize > jLatMax):
        if(j*tileSize > jLatMax):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[jLatMax % tileSize:, :] = 0
            vNew[jLatMax % tileSize:, :] = 0
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            uNew[:, :] = 0
            vNew[:, :] = 0
        else:
            uNew[:jLatMin % tileSize, :] = 0
            vNew[:jLatMin % tileSize, :] = 0
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
        imageio.imwrite('../tiles/%s_%s_%s_%s/%d/%d/%d.png' % (model, field, dateTimeSave,
                                                               depth, zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveTile():
    global zoom
    global xTile, yTile
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        iStart = math.floor(np.abs(xTile-xNC[0]).argmin()/tileSize)
        iEnd = math.floor(np.abs(xTile-xNC[-1]).argmin()/tileSize)+1
        jStart = math.floor(np.abs(yTile-yNC[0]).argmin()/tileSize)
        jEnd = math.floor(np.abs(yTile-yNC[-1]).argmin()/tileSize)+1
        iters = np.array(np.meshgrid(np.arange(iStart, iEnd),
                                     np.arange(jStart, jEnd))).T.reshape(-1, 2)
        #
        with multiprocessing.Pool() as p:
            p.starmap(saveImg, iters)


# For interpolation, NaN is not accepted
for i in np.arange(len(times)):
    global dateTimeSave, fu, fv
    time = times[i]
    dateTimeSave = datetime.utcfromtimestamp(time).strftime('%Y%m%d_%H')
    uzTmp = uz[i]
    uzTmp[np.isnan(uzTmp)] = 0
    fu = interpolate.interp2d(xNC, yNC, uzTmp, kind='linear')
    vzTmp = vz[i]
    vzTmp[np.isnan(vzTmp)] = 0
    fv = interpolate.interp2d(xNC, yNC, vzTmp, kind='linear')
    saveTile()
