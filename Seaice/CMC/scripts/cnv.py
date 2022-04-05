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
date = sys.argv[1]
hr = int(sys.argv[2])

dateSave = datetime.strptime(date, "%Y%m%d")
hrSave = hr
while(hrSave >= 24):
    dateSave += timedelta(days=1)
    hrSave -= 24

dateSave = datetime.strftime(dateSave, "%Y%m%d")


ncFile = Dataset(
    "CMC_gdwps_global_ICEC_SFC_0_latlon0.25x0.25_%s00_P%03d.nc" % (date, hr), 'r')
seaice = ncFile.variables['ci'][0].data
seaice[seaice < 0] = np.nan  # NaNs
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data


##  Crop -85 < lats < 85
latMask = np.bitwise_and(latNC>-85,latNC<85)
seaice = seaice[latMask, :]
latNC = latNC[latMask]


##  Switch west and east
tmp = np.copy(seaice[:,:720])
seaice[:,:720] = seaice[:,720:]
seaice[:,720:] = tmp
tmp = np.copy(lonNC[:720])
lonNC[:720] = lonNC[720:]
lonNC[720:] = tmp

lonNC[lonNC>=180] -= 360


# NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
seaiceMin = 0.
seaiceMax = 1.


# For interpolation, NaN is not accepted
seaice[np.isnan(seaice)] = seaiceMin-1
f = interpolate.interp2d(xNC, yNC, seaice, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/CMC_Seaice_%s_%02d/%d/%d' %
                        (dateSave, hrSave, zoom, i))
    seaiceNew = f(xTile[i*tileSize: (i+1)*tileSize],
                  yTile[j * tileSize:(j+1) * tileSize])
    seaiceNew[seaiceNew > seaiceMax] = seaiceMax
    seaiceNew[seaiceNew < seaiceMin] = seaiceMin
    if(np.max(seaiceNew) == 0):
        return
    else:
        # Coloring
        seaiceNewRounded = np.round(seaiceNew, 2)
        seaiceNewInt = (100*(seaiceNewRounded-seaiceMin)).astype(np.int8)
        seaiceNewInt[seaiceNewInt < 0] = 0
        seaiceNewInt[seaiceNewInt > 100 *
                     (seaiceMax-seaiceMin)] = 100*(seaiceMax-seaiceMin)
        seaiceColored = colors[seaiceNewInt]
        # Saving
        imageio.imwrite('../tiles/CMC_Seaice_%s_%02d/%d/%d/%d.png' % (dateSave, hrSave,
                                                                      zoom, i, 2**zoom-j-1), np.flipud(seaiceColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r, g, b,a in zip(np.linspace(color1[0], color2[0], n), np.linspace(color1[1], color2[1], n), np.linspace(color1[2], color2[2], n),np.linspace(color1[3], color2[3], n)):
        colors.append((r, g, b,a))
    return colors


# No Ice = transparent
color0 = [(0,0,0,0)]
colors1 = colorRange([255, 255, 255,255], [0,102,204,255], 100)

# All ranges
colors = np.array(color0+colors1)


def saveTile():
    global zoom, seaiceNew
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
