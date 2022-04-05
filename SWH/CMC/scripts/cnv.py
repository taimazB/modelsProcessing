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
dateSave = dateSave.strftime("%Y%m%d")

ncFile = Dataset(
    "CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_%s00_P%03d.nc" % (date, hr), 'r')
swh = ncFile.variables['swh'][0].data
swh[swh == ncFile.variables['swh']._FillValue] = np.nan
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data
lonNC[lonNC >= 180] -= 360
# Switch west and east
tmp = np.copy(swh[:, :720])
swh[:, :720] = swh[:, 720:]
swh[:, 720:] = tmp
tmp = np.copy(lonNC[:720])
lonNC[:720] = lonNC[720:]
lonNC[720:] = tmp

# Crop lats above 85N and below 85S
latMask = np.bitwise_and(latNC<=85, latNC>=-85)
latNC = latNC[latMask]
swh = swh[latMask]

# NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
swhMin = 0
swhMax = 10


# For interpolation, NaN is not accepted
swh[np.isnan(swh)] = -9999
f = interpolate.interp2d(xNC, yNC, swh, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/CMC_SWH_%s_%02d/%d/%d' %
                        (dateSave, hrSave, zoom, i))
    swhNew = f(xTile[i*tileSize: (i+1)*tileSize],
               yTile[j * tileSize:(j+1) * tileSize])
    swhNew[swhNew > swhMax] = swhMax
    swhNew[swhNew < 0] = np.nan
    swhNew[swhNew < swhMin] = swhMin
    if(np.isnan(np.nanmax(swhNew))):
        return
    else:
        # Coloring
        swhNewRounded = np.round(swhNew, 1)
        swhNewRounded[np.isnan(swhNewRounded)] = swhMin-.1
        swhNewInt = (10*(swhNewRounded-swhMin)).astype(np.int16)+1
        swhNewInt[swhNewInt < 0] = 0
        swhNewInt[swhNewInt > 10 *
                  (swhMax-swhMin)] = 10*(swhMax-swhMin)
        swhColored = colors[swhNewInt]
        # Saving
        imageio.imwrite('../tiles/CMC_SWH_%s_%02d/%d/%d/%d.png' % (dateSave, hrSave,
                                                                   zoom, i, 2**zoom-j-1), np.flipud(swhColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r, g, b, a in zip(np.linspace(color1[0], color2[0], n), np.linspace(color1[1], color2[1], n), np.linspace(color1[2], color2[2], n), np.linspace(color1[3], color2[3], n)):
        colors.append((r, g, b, a))
    return colors


##  Continents = black
color0 = [(0, 0, 0, 0)]

colors1 = colorRange([0, 51, 153, 255], [0, 255, 204, 255], 20)
colors2 = colorRange([0, 255, 204, 255], [51, 204, 51, 255], 20)
colors3 = colorRange([51, 204, 51, 255], [204, 204, 0, 255], 20)
colors4 = colorRange([204, 204, 0, 255], [204, 0, 0, 255], 20)
colors5 = colorRange([204, 0, 0, 255], [255, 204, 204, 255], 20)

# All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+colors5)


def saveTile():
    global zoom, swhNew
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
