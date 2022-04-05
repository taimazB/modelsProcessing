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
ncFile = Dataset("WMOP_Currents_%s.nc" % date, 'r')
times = ncFile.variables['ocean_time'][:].data
baseTime = datetime(1968, 5, 23)
u = ncFile.variables['u'][:].data
v = ncFile.variables['v'][:].data
latNC = ncFile.variables['lat_uv'][:].data
lonNC = ncFile.variables['lon_uv'][:].data
lonNC[lonNC > 180] -= 360


##  NC Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# Fixed min/max values for all levels and times
uvMin = -1.5
uvMax = 1.5


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg1(zoom, iTime, i, j, uv):
    date = (baseTime + timedelta(seconds=times[iTime])).strftime("%Y%m%d")
    hr = (baseTime + timedelta(seconds=times[iTime])).strftime("%H")
    devNull = os.system('mkdir -p ../tiles/WMOP_Currents_%s_%s/%d/%d' %
                        (date, hr, zoom, i))                        
    subUnew = uv[0][j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
    subVnew = uv[1][j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
    if(np.min(subUnew) == 127 and np.max(subUnew) == 127 and np.min(subVnew) == 127 and np.max(subVnew) == 127):
        return
    else:
        uvColored = np.empty(
            (subUnew.shape[0], subVnew.shape[1], 3), dtype=np.uint8)
        uvColored[:, :, 0] = subUnew[:, :]
        uvColored[:, :, 1] = subVnew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('../tiles/WMOP_Currents_%s_%s/%d/%d/%d.png' %
                        (date, hr, zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveImg2(zoom, iTime, i, j, iSub, uv):
    date = (baseTime + timedelta(seconds=times[iTime])).strftime("%Y%m%d")
    hr = (baseTime + timedelta(seconds=times[iTime])).strftime("%H")
    devNull = os.system(
        'mkdir -p ../tiles/WMOP_Currents_%s_%0s/%d/%d' % (date, hr, zoom, i+n*iSub))
    subUnew = uv[0][j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
    subVnew = uv[1][j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
    if(np.min(subUnew) == 127 and np.max(subUnew) == 127 and np.min(subVnew) == 127 and np.max(subVnew) == 127):
        return
    else:
        uvColored = np.empty(
            (subUnew.shape[0], subVnew.shape[1], 3), dtype=np.uint16)
        uvColored[:, :, 0] = subUnew[:, :]
        uvColored[:, :, 1] = subVnew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('../tiles/WMOP_Currents_%s_%s/%d/%d/%d.png' % (date, hr,
                                                                       zoom, i+n*iSub, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveTile(iTime):
    ut = u[iTime, :, :]
    vt = v[iTime, :, :]
    #
    # For interpolation, NaN is not accepted
    ut[np.isnan(ut)] = 0
    vt[np.isnan(vt)] = 0
    #
    fu = interpolate.interp2d(xNC, yNC, ut, kind='linear')
    fv = interpolate.interp2d(xNC, yNC, vt, kind='linear')
    #
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
        if zoom <= 5:
            uNew = fu(xTile, yTile)
            vNew = fv(xTile, yTile)
            ##  Interpolation adds unusual strips in the x direction -> Make them zero
            iXStart = np.argmin(np.abs(xTile-xMercator(lonNC[0])))
            iXEnd = np.argmin(np.abs(xTile-xMercator(lonNC[-1])))
            uNew[:,:iXStart] = 0
            uNew[:,iXEnd:] = 0
            vNew[:,:iXStart] = 0
            vNew[:,iXEnd:] = 0
            #
            uNew[uNew > uvMax] = uvMax
            uNew[uNew < uvMin] = uvMin
            vNew[vNew > uvMax] = uvMax
            vNew[vNew < uvMin] = uvMin
            #
            # Normalize values
            uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
            vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
            #
            #
            iters = np.array(np.meshgrid([zoom],[iTime], np.arange(2**zoom),
                                         np.arange(2**zoom))).T.reshape(-1, 4)
            itersList = [list(iter) for iter in iters]
            [iterList.append([uNew,vNew]) for iterList in itersList]
            #
            for iterList in itersList:
                saveImg1(*iterList)
            # poolSize = min(len(iters), 32)
            # with multiprocessing.Pool(poolSize) as p:
            #     p.starmap(saveImg1, itersList)
            #
            #
        else:  # For memory issues, need to break into chunks for zooms>=6
            xLength = n*tileSize  # Due to memory issue
            xChunks = int(xTile.size / xLength)
            for iSub in np.arange(xChunks):
                xSubTile = xTile[int(iSub*noOfPoints/xChunks)
                               :int((iSub+1)*noOfPoints/xChunks)]
                uNew = fu(xSubTile, yTile)
                vNew = fv(xSubTile, yTile)
                ##  Interpolation adds unusual strips in the x direction -> Make them zero
                iXStart = np.argmin(np.abs(xSubTile-xMercator(lonNC[0])))
                iXEnd = np.argmin(np.abs(xSubTile-xMercator(lonNC[-1])))
                uNew[:,:iXStart] = 0
                uNew[:,iXEnd:] = 0
                vNew[:,:iXStart] = 0
                vNew[:,iXEnd:] = 0
                print("##  Interpolating %d of %d done." % (iSub, xChunks-1))
                #
                uNew[uNew > uvMax] = uvMax
                uNew[uNew < uvMin] = uvMin
                vNew[vNew > uvMax] = uvMax
                vNew[vNew < uvMin] = uvMin
                #
                # Normalize values
                uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
                vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
                #
                #
                iters = np.array(np.meshgrid([zoom],[iTime], 
                    np.arange(n), np.arange(2**zoom), [iSub])).T.reshape(-1, 5)
                itersList = [list(iter) for iter in iters]
                [iterList.append([uNew,vNew]) for iterList in itersList]
                #
                for iterList in itersList:
                    saveImg2(*iterList)
                # poolSize = min(len(iters), 32)
                # with multiprocessing.Pool(poolSize) as p:
                #     p.starmap(saveImg2, iters)


with multiprocessing.Pool(13) as p:
    p.map(saveTile, np.arange(len(times)))

# print(tracemalloc.get_traced_memory())
