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

ncFile = Dataset("HYCOM_TS_%s_%02d.nc" % (date, hr),'r')


sst = np.array(ncFile.variables['water_temp'][0, 0])
sst = np.concatenate((sst[:,2250:], sst[:,:2250]), axis=1) # Switch west and east

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
sstMin = -2.1
sstMax = 35.


# For interpolation, NaN is not accepted
sst[np.isnan(sst)] = -9999  ##  Since we want to keep sstMin's
f = interpolate.interp2d(xNC, yNC, sst, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p %s/tiles/HYCOM_SST_%s_%02d/%d/%d' %
                        (path, date, hr, zoom, i))
    sstNew = f(xTile[i*tileSize: (i+1)*tileSize],
               yTile[j * tileSize:(j+1) * tileSize])
    sstNew[sstNew > sstMax] = sstMax
    sstNew[sstNew < sstMin] = np.nan
    # sstNew[sstNew < sstMin] = sstMin
    if(np.isnan(np.nanmax(sstNew))):
        return
    else:
        # Coloring
        sstNewRounded = np.round(sstNew, 1)
        sstNewInt = (10*(sstNewRounded-sstMin)).astype(np.int16)
        sstColored = colors[sstNewInt]
        # Saving
        imageio.imwrite('%s/tiles/HYCOM_SST_%s_%02d/%d/%d/%d.png' % (path, date, hr,
                                                                     zoom, i, 2**zoom-j-1), np.flipud(sstColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r,g,b,a in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n),np.linspace(color1[3],color2[3], n)):
        colors.append((r,g,b,a))
    return colors


##  no data = transparent
color0  = [(0,0,0,0)]

##  Purple range
colors1 = colorRange([204,0,204,255],[255,153,255,255],20)

##  Blue range
colors2 = colorRange([0,102,204,255],[102,255,204,255],100)

##  Green range
colors3 = colorRange([0,153,51,255],[204,255,102,255],100)

##  Yellow range
colors4 = colorRange([255,255,0,255],[255,153,51,255],100)

##  Red range
colors5 = colorRange([255,0,0,255],[255,204,204,255],50)

##  All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+colors5)


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
exit()
