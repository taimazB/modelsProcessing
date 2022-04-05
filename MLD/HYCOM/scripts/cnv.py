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


# MLD
ncMLD = Dataset("HYCOM_SUR_%s_%02d.nc" % (date, hr), 'r')
MLD = ncMLD.variables['mixed_layer_thickness'][0].data
missingValue = ncMLD.variables['mixed_layer_thickness']._FillValue
MLD[MLD == missingValue] = np.nan


##  latitude, longitude, depth
lonNC = ncMLD.variables['lon'][:].data
latNC = ncMLD.variables['lat'][:].data


# Switch west and east
MLD = np.concatenate((MLD[:, int(len(lonNC)/2):],
                      MLD[:, :int(len(lonNC)/2)]), axis=1)
lonNC = np.concatenate((lonNC[int(len(lonNC)/2):], lonNC[:int(len(lonNC)/2)]))
lonNC[lonNC >= 180] -= 360


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
MLDmin = 0
MLDmax = 500


# For interpolation, NaN is not accepted
MLD[np.isnan(MLD)] = -9999  ##  Since we want to keep MLDmin's
f = interpolate.interp2d(xNC, yNC, MLD, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p %s/tiles/HYCOM_MLD_%s_%02d/%d/%d' %
                        (path, date, hr, zoom, i))
    MLDnew = f(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    MLDnew[MLDnew > MLDmax] = MLDmax
    MLDnew[MLDnew < MLDmin] = np.nan
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            MLDnew[:,:] = np.nan
        else:
            MLDnew[:jLatMin % tileSize] = np.nan
    #
    if(np.isnan(np.nanmax(MLDnew))):
        return
    else:
        # Coloring
        MLDnewRounded = np.round(MLDnew, 1)
        MLDnewInt = (1*(MLDnewRounded-MLDmin)).astype(np.int16)
        MLDcolored = colors[MLDnewInt]
        # Saving
        imageio.imwrite('%s/tiles/HYCOM_MLD_%s_%02d/%d/%d/%d.png' % (path, date, hr, zoom, i, 2**zoom-j-1), np.flipud(MLDcolored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r,g,b,a in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n),np.linspace(color1[3],color2[3], n)):
        colors.append((r,g,b,a))
    return colors


##  no data = transparent
color0  = [(0,0,0,0)]

##  Purple range
colors1 = colorRange([204,0,204,255],[0,102,204,255],100)

##  Blue range
colors2 = colorRange([0,102,204,255],[0,153,51,255],100)

##  Green range
colors3 = colorRange([0,153,51,255],[255,255,0,255],100)

##  Yellow range
colors4 = colorRange([255,255,0,255],[255,0,0,255],100)

##  Red range
colors5 = colorRange([255,0,0,255],[255,204,204,255],100)

##  All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+colors5)


def saveTile():
    global zoom, MLDnew
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
