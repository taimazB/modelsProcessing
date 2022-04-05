import numpy as np
from netCDF4 import Dataset
import sys
import matplotlib.pyplot as plt
from numpy.core.arrayprint import set_string_function
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

ncFile = Dataset("HYCOM_TS_%s_%02d.nc" % (date, hr), 'r')


sss = np.array(ncFile.variables['salinity'][0, 0])
sss = np.concatenate((sss[:,2250:], sss[:,:2250]), axis=1) # Switch west and east

latNC = ncFile.variables['lat'][:].data
iLat85 = np.argmin(np.abs(latNC-85))  ## max lat = 85

lonNC = ncFile.variables['lon'][:].data
lonNC = np.concatenate((lonNC[2250:], lonNC[:2250])) # Switch west and east
lonNC[lonNC > 180] -= 360


# NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
sssMin = 30.
sssMax = 40.


# For interpolation, NaN is not accepted
sss[np.isnan(sss)] = -9999
f = interpolate.interp2d(xNC, yNC, sss, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p %s/tiles/HYCOM_SSS_%s_%02d/%d/%d' %
                        (path, date, hr, zoom, i))
    sssNew = f(xTile[i*tileSize: (i+1)*tileSize],
               yTile[j * tileSize:(j+1) * tileSize])
    sssNew[sssNew > sssMax] = sssMax
    sssNew[sssNew < 0] = np.nan
    sssNew[sssNew < sssMin] = sssMin
    if(np.isnan(np.nanmax(sssNew))):
        return
    else:
        # Coloring
        sssNewRounded = np.round(sssNew, 1)
        sssNewRounded[np.isnan(sssNewRounded)] = sssMin-.1
        sssNewInt = (10*(sssNewRounded-sssMin)).astype(np.int16)+1 ##  +1 because min value corresponds to colors[1]
        sssNewInt[sssNewInt < 0] = 0
        sssNewInt[sssNewInt > 10 *
                     (sssMax-sssMin)] = 10*(sssMax-sssMin)
        sssColored = colors[sssNewInt]
        # Saving
        imageio.imwrite('%s/tiles/HYCOM_SSS_%s_%02d/%d/%d/%d.png' % (path, date, hr,
                                                                     zoom, i, 2**zoom-j-1), np.flipud(sssColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r, g, b,a in zip(np.linspace(color1[0], color2[0], n), np.linspace(color1[1], color2[1], n), np.linspace(color1[2], color2[2], n),np.linspace(color1[3], color2[3], n)):
        colors.append((r, g, b,a))
    return colors


##  no data = black
color0 = [(0, 0, 0, 0)]

# Blue to Green range
colors1 = colorRange([0, 102, 204, 255], [204, 255, 102, 255], 50)

# Green to Orange range
colors2 = colorRange([204, 255, 102, 255], [255, 153, 51, 255], 50)


# All ranges
colors = np.array(color0+colors1+colors2)


def saveTile():
    global zoom, sssNew
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
        #
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
