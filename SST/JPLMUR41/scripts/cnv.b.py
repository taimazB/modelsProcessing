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
n = 8

# tracemalloc.start()
date = sys.argv[1]

ncFile = Dataset("JPLMUR41_SST_%s_09.nc" % date, 'r')
sst = ncFile.variables['analysed_sst'][0].data
missingValue = -32768
sst[sst==missingValue] = np.nan
sst -= 273.15  ## K -> C
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data
lonNC[lonNC > 180] -= 360


# NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
sstMin = -2
sstMax = 35



###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg1(i, j):
    devNull = os.system('mkdir -p ../tiles/JPLMUR41_SST_%s_09/%d/%d' %
                        (date, zoom, i))
    subSSTnew = sstNew[j *
                       tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
    if(np.max(subSSTnew) < sstMin):
        return
    else:
        # Coloring
        subSSTnew[subSSTnew<sstMin] = sstMin
        subSSTnewRounded = np.round(subSSTnew, 1)
        subSSTnewInt = (10*(subSSTnewRounded-sstMin)).astype(np.int16)
        subSSTnewInt[subSSTnewInt < 0] = 0
        subSSTnewInt[subSSTnewInt > 100 *
                     (sstMax-sstMin)] = 100*(sstMax-sstMin)
        subSSTcolored = colors[subSSTnewInt]
        # Saving
        imageio.imwrite('../tiles/JPLMUR41_SST_%s_09/%d/%d/%d.png' % (date,
                                                                     zoom, i, 2**zoom-j-1), np.flipud(subSSTcolored).astype(np.uint8))


def saveImg2(i, j, iSub):
    devNull = os.system(
        'mkdir -p ../tiles/JPLMUR41_SST_%s_09/%d/%d' % (date, zoom, i+n*iSub))
    subSSTnew = sstNew[j * tileSize:(j+1) *
                       tileSize, i*tileSize:(i+1)*tileSize]
    if(np.max(subSSTnew) == sstMin):
        return
    else:
        # Coloring
        subSSTnewRounded = np.round(subSSTnew, 1)
        subSSTnewInt = (10*(subSSTnewRounded-sstMin)).astype(np.int16)
        subSSTnewInt[subSSTnewInt < 0] = 0
        subSSTnewInt[subSSTnewInt > 100 *
                     (sstMax-sstMin)] = 100*(sstMax-sstMin)
        subSSTcolored = colors[subSSTnewInt]
        # Saving
        imageio.imwrite('../tiles/JPLMUR41_SST_%s_09/%d/%d/%d.png' % (date, 
                                                                     zoom, i+n*iSub, 2**zoom-j-1), np.flipud(subSSTcolored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r,g,b in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n)):
        colors.append((r,g,b))
    return colors


##  Continents = black
color0  = [(0,0,0)]

##  Purple range
colors1 = colorRange([204,0,204],[255,153,255],20)

##  Blue range
colors2 = colorRange([0,102,204],[102,255,204],100)

##  Green range
colors3 = colorRange([0,153,51],[204,255,102],100)

##  Yellow range
colors4 = colorRange([255,255,0],[255,153,51],100)

##  Red range
colors5 = colorRange([255,0,0],[255,204,204],50)

##  All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+colors5)


def saveTile():
    # For interpolation, NaN is not accepted
    sst[np.isnan(sst)] = sstMin-1
    #
    f = interpolate.interp2d(xNC, yNC, sst, kind='linear')
    #
    #
    global zoom, sstNew
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        #
        if zoom <= 5:
            sstNew = f(xTile, yTile)
            #
            sstNew[sstNew > sstMax] = sstMax
            sstNew[sstNew < sstMin] = sstMin
            #
            #
            iters = np.array(np.meshgrid(np.arange(2**zoom),
                                         np.arange(2**zoom))).T.reshape(-1, 2)
            #
            poolSize = min(len(iters), 32)
            with multiprocessing.Pool(poolSize) as p:
                p.starmap(saveImg1, iters)
            #
            #
        else:  # For memory issues, need to break into chunks for zooms>=6
            xLength = n*tileSize  # Due to memory issue
            xChunks = int(xTile.size / xLength)
            for iSub in np.arange(xChunks):
                xSubTile = xTile[int(iSub*noOfPoints/xChunks):int((iSub+1)*noOfPoints/xChunks)]
                sstNew = f(xSubTile, yTile)
                print("##  Interpolating %d of %d done." % (iSub, xChunks-1))
                #
                sstNew[sstNew > sstMax] = sstMax
                sstNew[sstNew < sstMin] = sstMin
                #
                #
                iters = np.array(np.meshgrid(
                    np.arange(n), np.arange(2**zoom), [iSub])).T.reshape(-1, 3)
                #
                poolSize = min(len(iters), 32)
                with multiprocessing.Pool(poolSize) as p:
                    p.starmap(saveImg2, iters)


saveTile()
# print(tracemalloc.get_traced_memory())
# tracemalloc.stop()
exit()
