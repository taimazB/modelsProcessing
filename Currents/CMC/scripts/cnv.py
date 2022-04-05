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
import subprocess


maxTileLat = 85.0511287798066
tileSize = 512  # px
minZoom = 2
maxZoom = 7

# tracemalloc.start()
modelDate = sys.argv[1]
modelHour = sys.argv[2]
hr = int(sys.argv[3])


dateSave = datetime.strftime(datetime.strptime(modelDate+modelHour,'%Y%m%d%H') + timedelta(hours=hr), "%Y%m%d_%H")


missingValue = -9e+33


inputFile = "CMC_coupled-rdps-stlawrence-ocean_latlon0.02x0.03_%s%s_P%03d.nc" % (modelDate, modelHour, hr)
ncFile = Dataset(inputFile, 'r')
u = ncFile.variables['ocu'][0, 0].data
u[u == missingValue] = np.nan
v = ncFile.variables['ocv'][0, 0].data
v[v == missingValue] = np.nan


##  latitude and longitude
latNC = np.array(ncFile.variables['lat'])
lonNC = np.array(ncFile.variables['lon'])
lonNC[lonNC > 180] -= 360


##  Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
uvMin = -1
uvMax = 1


# For interpolation, NaN is not accepted
u[np.isnan(u)] = 0
v[np.isnan(v)] = 0
fu = interpolate.interp2d(xNC, yNC, u, kind='linear')
fv = interpolate.interp2d(xNC, yNC, v, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/CMC_Currents_%s/%d/%d' %
                        (dateSave, zoom, i))
    uNew = fu(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    vNew = fv(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    uNew[uNew > uvMax] = uvMax
    uNew[uNew < uvMin] = uvMin
    vNew[vNew > uvMax] = uvMax
    vNew[vNew < uvMin] = uvMin
    #
    # To trim the interpolation tail from the right side
    iLonMax = np.argmin(np.abs(xTile-xMercator(lonNC[-1])))
    if((i+1)*tileSize > iLonMax):
        if(i*tileSize > iLonMax):
            uNew[:,:] = 0
            vNew[:,:] = 0
        else:
            uNew[:,iLonMax % tileSize:] = 0
            vNew[:,iLonMax % tileSize:] = 0
    #
    # To trim the interpolation tail from the left side
    iLonMin = np.argmin(np.abs(xTile-xMercator(lonNC[0])))
    if(i*tileSize < iLonMin):
        if((i+1)*tileSize < iLonMin):
            uNew[:,:] = 0
            vNew[:,:] = 0
        else:
            uNew[:,:iLonMin % tileSize] = 0
            vNew[:,:iLonMin % tileSize] = 0
    #
    # To trim the interpolation tail from the top side
    jLatMax = np.argmin(np.abs(yTile-yMercator(latNC[-1])))
    if((j+1)*tileSize > jLatMax):
        if(j*tileSize > jLatMax):
            uNew[:,:] = 0
            vNew[:,:] = 0
        else:
            uNew[jLatMax % tileSize:,:] = 0
            vNew[jLatMax % tileSize:,:] = 0
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            uNew[:,:] = 0
            vNew[:,:] = 0
        else:
            uNew[:jLatMin % tileSize,:] = 0
            vNew[:jLatMin % tileSize,:] = 0
    #
    # Normalize
    uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    #
    if(np.min(uNew) == 127 and np.max(uNew) == 127 and np.min(vNew) == 127 and np.max(vNew) == 127):
        return
    else:
        # Coloring
        uvColored = np.empty(
            (uNew.shape[0], uNew.shape[1], 3), dtype=np.uint8)
        uvColored[:, :, 0] = uNew[:, :]
        uvColored[:, :, 1] = vNew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('../tiles/CMC_Currents_%s/%d/%d/%d.png' % (dateSave, zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


# def saveImg2(i, j, iSub):
#     devNull = os.system(
#         'mkdir -p ../tiles/CMC_Currents_%s_%02d/%d/%d' % (dateSave, hrSave,  zoom, i+n*iSub))
#     subUnew = uNew[j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
#     subVnew = vNew[j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
#     ##  Only save if there is non-zero data
#     if(np.min(subUnew)==127 and np.max(subUnew)==127 and np.min(subVnew)==127 and np.max(subVnew)==127):
#         return
#     else:
#         uvColored = np.empty(
#             (subUnew.shape[0], subVnew.shape[1], 3), dtype=np.uint16)
#         uvColored[:, :, 0] = subUnew[:, :]
#         uvColored[:, :, 1] = subVnew[:, :]
#         uvColored[:, :, 2] = 0
#         imageio.imwrite('../tiles/CMC_Currents_%s_%02d/%d/%d/%d.jpg' % (dateSave, hrSave,zoom, i+n*iSub, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveTile():
    # It's only surface, so no averaging
    # uz = uGlob
    # vz = vGlob
    #
    # For interpolation, NaN is not accepted
    # uz[np.isnan(uz)] = 0
    # vz[np.isnan(vz)] = 0
    #
    # fu = interpolate.interp2d(x, y, uz, kind='linear')
    # fv = interpolate.interp2d(x, y, vz, kind='linear')
    #
    #
    global zoom, uNew, vNew
    global xTile, yTile
    for zoom in np.arange(minZoom, maxZoom+1):
        print("--  Start zoom %d" % zoom)
        noOfPoints = 2**zoom*tileSize
        #
        xTile = np.linspace(xMercator(-180),
                            xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat),
                            yMercator(maxTileLat), noOfPoints)
        # xx = np.linspace(xMercator(-180),
        #                  xMercator(180), noOfPoints)
        # yy = np.linspace(yMercator(-maxTileLat),
        #                  yMercator(maxTileLat), noOfPoints)
        #
        # if zoom <= 5:
        #     uNew = fu(xx, yy)
        #     vNew = fv(xx, yy)
        #     #
        #     uNew[uNew > uvMax] = uvMax
        #     uNew[uNew < uvMin] = uvMin
        #     vNew[vNew > uvMax] = uvMax
        #     vNew[vNew < uvMin] = uvMin
        #     #
        #     # Normalize values
        #     uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
        #     vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
        #
        #
        iters = np.array(np.meshgrid(np.arange(2**zoom),
                         np.arange(2**zoom))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)
            #
            #
        # else:  # For memory issues, need to break into chunks for zooms>=6
        #     xLength = n*tileSize  # Due to memory issue
        #     xChunks = int(xx.size / xLength)
        #     for iSub in np.arange(xChunks):
        #         xxSub = xx[int(iSub*noOfPoints/xChunks)                           :int((iSub+1)*noOfPoints/xChunks)]
        #         uNew = fu(xxSub, yy)
        #         vNew = fv(xxSub, yy)
        #         print("##  Interpolating %d of %d done." % (iSub+1, xChunks))
        #         #
        #         uNew[uNew > uvMax] = uvMax
        #         uNew[uNew < uvMin] = uvMin
        #         vNew[vNew > uvMax] = uvMax
        #         vNew[vNew < uvMin] = uvMin
        #         #
        #         # Normalize values
        #         uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
        #         vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
        #         #
        #         #
        #         iters = np.array(np.meshgrid(
        #             np.arange(n), np.arange(2**zoom), [iSub])).T.reshape(-1, 3)
        #         #
        #         poolSize = min(len(iters), 32)
        #         with multiprocessing.Pool(poolSize) as p:
        #             p.starmap(saveImg2, iters)


saveTile()

##  Rename input file
subprocess.call('mv -v %s CMC_Currents_%s.nc' % (inputFile, dateSave), shell=True)

# print(tracemalloc.get_traced_memory())
# tracemalloc.stop()
