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
    

# Seaice
ncSeaice = Dataset("RTOFS_Seaice_%s_%03d.nc" % (date, hr), 'r')
seaice = ncSeaice.variables['ice_coverage']
missingValue = seaice._FillValue
seaice = seaice[0].data
seaice[seaice == missingValue] = np.nan


##  latitude, longitude, depth
lonNC = ncSeaice.variables['lon'][:].data
latNC = ncSeaice.variables['lat'][:].data


# Switch west and east
# seaice = np.concatenate((seaice[:, int(len(lonNC)/2):],
#                       seaice[:, :int(len(lonNC)/2)]), axis=1)
# lonNC = np.concatenate((lonNC[int(len(lonNC)/2):], lonNC[:int(len(lonNC)/2)]))
lonNC[lonNC >= 180] -= 360


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
seaiceMin = 0
seaiceMax = 1


# For interpolation, NaN is not accepted
seaice[np.isnan(seaice)] = -9999  ##  Since we want to keep sstMin's
f = interpolate.interp2d(xNC, yNC, seaice, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    try:
        if(yTile[j*tileSize: (j+1)*tileSize].min()>yNC.max() or
           yTile[j*tileSize: (j+1)*tileSize].max()<yNC.min()):
            return
    except:
        return
    devNull = os.system('mkdir -p ../tiles/RTOFS_Seaice_%s_%02d/%d/%d' %
                        (dateSave, hrSave, zoom, i))
    seaiceNew = f(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    seaiceNew[seaiceNew > seaiceMax] = seaiceMax
    seaiceNew[seaiceNew < seaiceMin] = np.nan
    #
    if(np.isnan(np.nanmax(seaiceNew))):
        return
    else:
        # Coloring
        seaiceNewRounded = np.round(seaiceNew, 2)
        seaiceNewInt = (100*(seaiceNewRounded-seaiceMin)).astype(np.int16)
        seaiceColored = colors[seaiceNewInt]
        # Saving
        imageio.imwrite('../tiles/RTOFS_Seaice_%s_%02d/%d/%d/%d.png' % (dateSave, hrSave,zoom, i, 2**zoom-j-1), np.flipud(seaiceColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r,g,b,a in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n),np.linspace(color1[3],color2[3], n)):
        colors.append((r,g,b,a))
    return colors


# No Ice = transparent
color0 = [(0,0,0,0)]
# colors1 = colorRange([255, 255, 255,255],[0,102,204,255], 100)
colors1 = colorRange([102,179,255,255],[0,51,102,255], 100)

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
        # iStart = max(math.floor(np.abs(xTile-xNC[0]).argmin()/tileSize)-1,0)  ## unlimited lon
        # iEnd = math.ceil(np.abs(xTile-xNC[-1]).argmin()/tileSize)+1
        # jStart = max(math.floor(np.abs(xTile-yNC[0]).argmin()/tileSize)-1,0)
        # jEnd = math.ceil(np.abs(xTile-yNC[-1]).argmin()/tileSize)+1
        iters = np.array(np.meshgrid(np.arange(2**zoom),np.arange(2**zoom))).T.reshape(-1,2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)


saveTile()
