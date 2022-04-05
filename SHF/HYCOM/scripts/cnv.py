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


# tracemalloc.start()
dateHr = sys.argv[1].split('_')
date = dateHr[0]
hr = int(dateHr[1])
path = sys.argv[2]


# SHF
ncSHF = Dataset("HYCOM_SUR_%s_%02d.nc" % (date, hr), 'r')
SHF = ncSHF.variables['qtot'][0].data
missingValue = ncSHF.variables['qtot']._FillValue
SHF[SHF == missingValue] = np.nan


##  latitude, longitude, depth
lonNC = ncSHF.variables['lon'][:].data
latNC = ncSHF.variables['lat'][:].data


# Switch west and east
SHF = np.concatenate((SHF[:, int(len(lonNC)/2):],
                      SHF[:, :int(len(lonNC)/2)]), axis=1)
lonNC = np.concatenate((lonNC[int(len(lonNC)/2):], lonNC[:int(len(lonNC)/2)]))
lonNC[lonNC >= 180] -= 360


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
SHFmin = -1500
SHFmax = 1500


# For interpolation, NaN is not accepted
SHF[np.isnan(SHF)] = -9999  ##  Since we want to keep SHFmin's
f = interpolate.interp2d(xNC, yNC, SHF, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p %s/tiles/HYCOM_SHF_%s_%02d/%d/%d' %
                        (path, date, hr, zoom, i))
    SHFnew = f(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    SHFnew[SHFnew > SHFmax] = SHFmax
    SHFnew[SHFnew < SHFmin] = np.nan
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            SHFnew[:,:] = np.nan
        else:
            SHFnew[:jLatMin % tileSize] = np.nan
    #
    if(np.isnan(np.nanmax(SHFnew))):
        return
    else:
        # Coloring
        SHFnewRounded = np.round(SHFnew, 1)
        SHFnewInt = (1*(SHFnewRounded-SHFmin)).astype(np.int16)
        SHFcolored = colors[SHFnewInt]
        # Saving
        imageio.imwrite('%s/tiles/HYCOM_SHF_%s_%02d/%d/%d/%d.png' % (path, date, hr, zoom, i, 2**zoom-j-1), np.flipud(SHFcolored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r,g,b,a in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n),np.linspace(color1[3],color2[3], n)):
        colors.append((r,g,b,a))
    return colors


##  no data = transparent
color0  = [(0,0,0,0)]

colors1 = colorRange([255,0,255,255],[0,153,255,255],500)
colors2 = colorRange([0,153,255,255],[51,204,51,255],500)
colors3 = colorRange([51,204,51,255],[255,255,255,255],500)
colors4 = colorRange([255,255,255,255],[255,255,0,255],500)
colors5 = colorRange([255,255,0,255],[255,102,0,255],500)
colors6 = colorRange([255,102,0,255],[255,0,0,255],500)

##  All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+colors5+colors6)


def saveTile():
    global zoom, SHFnew
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
        iters = np.array(np.meshgrid(np.arange(2**zoom),
                                     np.arange(2**zoom))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)


saveTile()
