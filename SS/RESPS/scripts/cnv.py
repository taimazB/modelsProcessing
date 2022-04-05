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


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7

# tracemalloc.start()
date = sys.argv[1]
hr = int(sys.argv[2])

dateSave = date
hrSave = hr
while (hrSave>=24):
    dateSave = datetime.strftime(datetime.strptime(
        dateSave, "%Y%m%d") + timedelta(days=1), "%Y%m%d")
    hrSave = hrSave - 24

ncFile = Dataset("RESPS_SS_%s_%03d.nc" % (date, hr), 'r')
ss = ncFile.variables['etas']
missingValue = ss.missing_value
ss = np.mean(ss, axis=0)[0].data  ##  Ensemble mean
ss[ss >= missingValue] = np.nan
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data
lonNC[lonNC > 180] -= 360


# NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
ssMin = -1
ssMax = 1


# For interpolation, NaN is not accepted
ss[np.isnan(ss)] = -9E+30
f = interpolate.interp2d(xNC, yNC, ss, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/RESPS_SS_%s_%02d/%d/%d' %
                        (dateSave, hrSave, zoom, i))
    ssNew = f(xTile[i*tileSize: (i+1)*tileSize],
               yTile[j * tileSize:(j+1) * tileSize])
    ssNew[ssNew > ssMax] = ssMax
    ssNew[ssNew < -1000] = np.nan
    ssNew[ssNew < ssMin] = ssMin
    #
    if(i == iStart):
        iLonMin = np.argmin(np.abs(xTile-xMercator(lonNC[0])))
        ssNew[:, :iLonMin % tileSize] = np.nan
    if(i == iEnd):
        iLonMax = np.argmin(np.abs(xTile-xMercator(lonNC[-1])))
        ssNew[:, iLonMax % tileSize:] = np.nan
    if(j == jStart):
        jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
        ssNew[:jLatMin % tileSize, :] = np.nan
    if(j == jEnd):
        jLatMax = np.argmin(np.abs(yTile-yMercator(latNC[-1])))
        ssNew[jLatMax % tileSize:, :] = np.nan
    #
    if(np.isnan(np.nanmax(ssNew))):
        return
    else:
        # Coloring
        ssNewRounded = np.round(ssNew, 2)
        ssNewInt = (100*(ssNewRounded-ssMin)).astype(np.int16)
        ssNewInt[ssNewInt < 0] = 0
        ssNewInt[ssNewInt > 100 *
                  (ssMax-ssMin)] = 100*(ssMax-ssMin)
        ssColored = colors[ssNewInt]
        # Saving
        imageio.imwrite('../tiles/RESPS_SS_%s_%02d/%d/%d/%d.png' % (dateSave, hrSave,
                                                                      zoom, i, 2**zoom-j-1), np.flipud(ssColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r, g, b,a in zip(np.linspace(color1[0], color2[0], n), np.linspace(color1[1], color2[1], n), np.linspace(color1[2], color2[2], n),np.linspace(color1[3], color2[3], n)):
        colors.append((r, g, b,a))
    return colors


# no data = transparent
color0 = [(0, 0, 0, 0)]
colors1 = colorRange([204, 51, 204,255], [0, 51, 204,255], 50)
colors2 = colorRange([0, 51, 204,255], [255, 255, 255,255], 50)
colors3 = colorRange([255, 255, 255,255], [255, 204, 0,255], 50)
colors4 = colorRange([255,204, 255,255], [204, 51, 0,255], 50)

# All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4)


def saveTile():
    global zoom
    global xTile, yTile
    global iStart, iEnd, jStart, jEnd
    #
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        #
        iStart = math.floor(np.abs(xTile-xNC[0]).argmin()/tileSize)
        iEnd = math.floor(np.abs(xTile-xNC[-1]).argmin()/tileSize)
        jStart = math.floor(np.abs(xTile-yNC[0]).argmin()/tileSize)
        jEnd = math.floor(np.abs(xTile-yNC[-1]).argmin()/tileSize)
        iters = np.array(np.meshgrid(np.arange(iStart, iEnd+1),
                                     np.arange(jStart, jEnd+1))).T.reshape(-1, 2)
        #
        # poolSize = min(len(iters))
        with multiprocessing.Pool() as p:
            p.starmap(saveImg, iters)


saveTile()
# print(tracemalloc.get_traced_memory())
# tracemalloc.stop()
