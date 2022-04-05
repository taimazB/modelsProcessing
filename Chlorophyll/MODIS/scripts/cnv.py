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
from global_land_mask import globe


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7

# tracemalloc.start()
date = sys.argv[1] ## eg 20201217

ncFile = Dataset("MODIS_Chlorophyll_%s.nc" % date, 'r')
chlr = ncFile.variables['chlor_a'][:,:].data
##  missing value: <0
chlr[chlr<0] = np.nan
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data


##  Mask chlorophyll over land; ie, no river, no lake
# lonMesh, latMesh = np.meshgrid(lonNC, latNC)
# landMask = globe.is_land(latMesh, lonMesh)
# chlr[landMask] = np.nan


# NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
chlrMin = -3 ## log(0.001)
chlrMax = 3 ## log(1000.)


# For interpolation, NaN is not accepted
chlr[np.isnan(chlr)] = 10**-10
f = interpolate.interp2d(xNC, yNC, chlr, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/MODIS_Chlorophyll_%s_12/%d/%d' % (date, zoom, i))
    chlrNew = f(xTile[i*tileSize: (i+1)*tileSize],yTile[j * tileSize:(j+1) * tileSize])
    chlrLog = np.log10(chlrNew)
    chlrLog[chlrLog<chlrMin] = np.nan
    if(np.isnan(np.nanmax(chlrLog))):
        return
    else:
        # Coloring
        chlrLogRounded = np.round(chlrLog, 2)
        chlrLogInt = (100*(chlrLogRounded-chlrMin)).astype(np.int)
        chlrLogInt[chlrLogInt<0] = 0
        chlrColored = colors[chlrLogInt]
        # Saving
        imageio.imwrite('../tiles/MODIS_Chlorophyll_%s_12/%d/%d/%d.png' % (date, zoom, i, 2**zoom-j-1), np.flipud(chlrColored).astype(np.uint8))



def colorRange(color1, color2, n):
    colors = []
    for r, g, b,a in zip(np.linspace(color1[0], color2[0], n), np.linspace(color1[1], color2[1], n), np.linspace(color1[2], color2[2], n),np.linspace(color1[3], color2[3], n)):
        colors.append((r, g, b,a))
    return colors


# no data = transparent
color0 = [(0, 0, 0, 0)]

##  Green range
colors1 = colorRange([0,51,0,255], [153,255,153,255], 200)

##  Yellow range
colors2 = colorRange([255,255,0,255], [255,153,51,255], 200)

##  Red range
colors3 = colorRange([255,0,0,255], [255,204,204,255], 200)

##  All ranges
colors = np.array(color0+colors1+colors2+colors3)


def saveTile():
    global zoom, sstNew
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
