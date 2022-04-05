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


field = 'Seaice'
model = 'Barents'

maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7


# tracemalloc.start()
date = sys.argv[1]


nc = Dataset("%s_%s_%s_regrid.nc" % (field, model, date), 'r')
var = nc.variables['ice_concentration'][:].data
times = nc.variables['time'][:].data
missingValue = nc['ice_concentration'].missing_value

var[var == missingValue] = np.nan

##  latitude, longitude, depth
lonNC = nc.variables['lon'][:].data
latNC = nc.variables['lat'][:].data


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
seaiceMin = 0
seaiceMax = 1


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
            print('Exit 1')
            return
    except:
        print('Exit 2')
        return
    devNull = os.system('mkdir -p ../tiles/%s_%s_%s/%d/%d' %
                        (model, field, dateTimeSave, zoom, i))
    seaiceNew = f(xTile[i*tileSize: (i+1)*tileSize],
                  yTile[j * tileSize:(j+1) * tileSize])
    seaiceNew[seaiceNew > seaiceMax] = seaiceMax
    seaiceNew[seaiceNew < seaiceMin] = np.nan
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            seaiceNew[:, :] = np.nan
        else:
            seaiceNew[:jLatMin % tileSize] = np.nan
    #
    if(np.isnan(np.nanmax(seaiceNew))):
        return
    else:
        # Coloring
        seaiceNewRounded = np.round(seaiceNew, 2)
        seaiceNewInt = (100*(seaiceNewRounded-seaiceMin)).astype(np.int16)
        seaiceColored = colors[seaiceNewInt]
        # Saving
        imageio.imwrite('../tiles/%s_%s_%s/%d/%d/%d.png' % (model, field, dateTimeSave,
                                                                 zoom, i, 2**zoom-j-1), np.flipud(seaiceColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r, g, b, a in zip(np.linspace(color1[0], color2[0], n), np.linspace(color1[1], color2[1], n), np.linspace(color1[2], color2[2], n), np.linspace(color1[3], color2[3], n)):
        colors.append((r, g, b, a))
    return colors


# No Ice = transparent
color0 = [(0, 0, 0, 0)]
# colors1 = colorRange([255, 255, 255,255],[0,102,204,255], 100)
colors1 = colorRange([102, 179, 255, 255], [0, 51, 102, 255], 100)

# All ranges
colors = np.array(color0+colors1)


def saveTile():
    global zoom
    global xTile, yTile
    #
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
    global dateTimeSave, f
    time = times[i]
    dateTimeSave = datetime.utcfromtimestamp(time).strftime('%Y%m%d_%H')
    varTmp = var[i]
    varTmp[np.isnan(varTmp)] = -9999  # Since we want to keep sstMin's
    f = interpolate.interp2d(xNC, yNC, varTmp, kind='linear')
    saveTile()
