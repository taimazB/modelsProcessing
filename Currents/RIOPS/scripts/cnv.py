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

if (hr < 24):
    dateSave = date
    hrSave = hr
elif (hr < 48):
    dateSave = datetime.strftime(datetime.strptime(
        date, "%Y%m%d") + timedelta(days=1), "%Y%m%d")
    hrSave = hr - 24
elif (hr < 72):
    dateSave = datetime.strftime(datetime.strptime(
        date, "%Y%m%d") + timedelta(days=2), "%Y%m%d")
    hrSave = hr - 48


# depthRanges = [[0,10],[10,50],[50,100],[100,200],[200,500],[500,1000],[1000,1500],[1500,2000],[50,20000]]
depthRanges = [[0, 10], [20, 200], [50, 1000]]
missingValue = 1e+20


# U
ncU = Dataset("CMC_RIOPS_ux_%s_%03d.nc" % (date, hr), 'r')
ux = ncU.variables['vozocrtx'][0].data
ux[ux == missingValue] = np.nan


# V
ncV = Dataset("CMC_RIOPS_vy_%s_%03d.nc" % (date, hr), 'r')
vy = ncV.variables['vomecrty'][0].data
vy[vy == missingValue] = np.nan


##  latitude, longitude, depth
lonNC = ncU.variables['lon'][:].data
latNC = ncU.variables['lat'][:].data
depths = ncU.variables['depth'][:].data


# ux,vx -> u,v
# longitude[i,j]<260:   theta = (longitude[i,j] + 100) * np.pi/180
# longitude[i,j]>=260:  theta = (longitude[i,j] - 260) * np.pi/180
theta = lonNC * np.pi/180
theta[lonNC < 260] += 100*np.pi/180
theta[lonNC >= 260] -= 260*np.pi/180
u = ux*np.cos(theta) + vy*np.sin(theta)  # lat: 30 - 90  (750 points)
v = -ux*np.sin(theta) + vy*np.cos(theta)  # ...
del ux, vy

# Global array for jpg (lat: ~-85 - ~85)
# latTile = np.arange(-maxTileLat, maxTileLat, 0.08)
# lonTile = np.arange(-180, 180, 0.08)
# uGlob = np.empty((len(depths), len(latTile), len(lonTile)))
# vGlob = np.empty((len(depths), len(latTile), len(lonTile)))

# iLatTile30 = np.argmin(np.abs(latTile-30))  # index of 30N in the latTile
# iLatNC85 = np.argmin(np.abs(latNC-maxTileLat))  # index of maxTile in the latNC

# Switch west and east
u = np.concatenate((u[:, :, int(len(lonNC)/2):],
                   u[:, :, :int(len(lonNC)/2)]), axis=2)
v = np.concatenate((v[:, :, int(len(lonNC)/2):],
                   v[:, :, :int(len(lonNC)/2)]), axis=2)
lonNC = np.concatenate((lonNC[int(len(lonNC)/2):], lonNC[:int(len(lonNC)/2)]))
lonNC[lonNC >= 180] -= 360
# vGlob[:, iLatTile30:, :] = np.concatenate((
#     v[:, :iLatNC85+1, int(len(lonTile)/2):], v[:, :iLatNC85+1, :int(len(lonTile)/2)]), axis=2)
# del u, v  ##  DO NOT del; needed later


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# For interpolation
# xx = np.linspace(np.min(x), np.max(x), len(lonTile))
# yy = np.linspace(np.min(y), np.max(y), len(latTile))


# Fixed min/max values for all levels and times
uvMin = -3.
uvMax = 3.


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p ../tiles/RIOPS_Currents_%s_%02d_%05d-%05d/%d/%d' %
                        (dateSave, hrSave, depthRange[0], depthRange[1], zoom, i))
    uNew = fu(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    vNew = fv(xTile[i*tileSize: (i+1)*tileSize],
              yTile[j * tileSize:(j+1) * tileSize])
    uNew[uNew > uvMax] = uvMax
    uNew[uNew < uvMin] = uvMin
    vNew[vNew > uvMax] = uvMax
    vNew[vNew < uvMin] = uvMin
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile-yMercator(latNC[0])))
    if(j*tileSize < jLatMin):
        if((j+1)*tileSize < jLatMin):
            uNew[:,:] = 0
            vNew[:,:] = 0
        else:
            uNew[:jLatMin % tileSize] = 0
            vNew[:jLatMin % tileSize] = 0
    #
    # Normalize
    uNew = (255*(uNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    vNew = (255*(vNew-uvMin)/(uvMax-uvMin)).astype(np.uint)
    #
    if(np.min(uNew) == 127 and np.max(uNew) == 127 and np.min(vNew) == 127 and np.max(vNew) == 127):
        return
    else:
        uvColored = np.empty(
            (uNew.shape[0], vNew.shape[1], 3), dtype=np.uint8)
        uvColored[:, :, 0] = uNew[:, :]
        uvColored[:, :, 1] = vNew[:, :]
        uvColored[:, :, 2] = 0
        imageio.imwrite('../tiles/RIOPS_Currents_%s_%02d_%05d-%05d/%d/%d/%d.png' % (dateSave, hrSave,
                        depthRange[0], depthRange[1], zoom, i, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


# def saveImg2(i, j, iSub):
#     devNull = os.system(
#         'mkdir -p ../tiles/RIOPS_Currents_%s_%02d_%05d-%05d/%d/%d' % (dateSave, hrSave, depthRange[0], depthRange[1], zoom, i+n*iSub))
#     subUnew = uNew[j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
#     subVnew = vNew[j*tileSize:(j+1) * tileSize, i*tileSize:(i+1)*tileSize]
#     if(np.min(subUnew)==127 and np.max(subUnew)==127 and np.min(subVnew)==127 and np.max(subVnew)==127):
#         return
#     else:
#         uvColored = np.empty(
#             (subUnew.shape[0], subVnew.shape[1], 3), dtype=np.uint16)
#         uvColored[:, :, 0] = subUnew[:, :]
#         uvColored[:, :, 1] = subVnew[:, :]
#         uvColored[:, :, 2] = 0
#         imageio.imwrite('../tiles/RIOPS_Currents_%s_%02d_%05d-%05d/%d/%d/%d.jpg' % (dateSave, hrSave,depthRange[0], depthRange[1], zoom, i+n*iSub, 2**zoom-j-1), np.flipud(uvColored).astype(np.uint8))


def saveTile(depthRange):
    global zoom, uz, vz
    global xTile, yTile, fu, fv
    uz = np.nanmean(u[np.bitwise_and(
        depths >= depthRange[0], depths < depthRange[1]), :, :], axis=0)
    vz = np.nanmean(v[np.bitwise_and(
        depths >= depthRange[0], depths < depthRange[1]), :, :], axis=0)
    #
    # For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    fu = interpolate.interp2d(xNC, yNC, uz, kind='linear')
    fv = interpolate.interp2d(xNC, yNC, vz, kind='linear')
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
        iters = np.array(np.meshgrid(np.arange(2**zoom),
                                     np.arange(2**zoom))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)


global depthRange
for depthRange in depthRanges:
    saveTile(depthRange)


#############################################
# Average depth for forecast/hindcast files
# Only if hr<24
# if (hr<24):
def writeNC(depth,u,v):
    # Write netCDF
    # open a netCDF file to write
    fileName = "PP/RIOPS_Currents_%s_%s_%02d.nc" % (depth, dateSave, hrSave)
    ncout = Dataset(fileName, 'w', format='NETCDF4')


    # define axis size
    ncout.createDimension('x', len(lonNew))
    ncout.createDimension('y', len(latNew))

    # create latitude axis
    latitude = ncout.createVariable('latitude', 'double', ('y'))
    latitude.standard_name = 'latitude'
    latitude.long_name = 'latitude'
    latitude.units = 'degrees_north'
    latitude.axis = 'Y'

    # create longitude axis
    longitude = ncout.createVariable('longitude', 'double', ('x'))
    longitude.standard_name = 'longitude'
    longitude.long_name = 'longitude'
    longitude.units = 'degrees_east'
    longitude.axis = 'X'

    # create variable array
    uout = ncout.createVariable('u', 'double', ('y', 'x'))
    uout.long_name = 'zonal velocity'
    uout.units = 'm/s'
    uout.coordinates = "latitude longitude"

    vout = ncout.createVariable('v', 'double', ('y', 'x'))
    vout.long_name = 'meridional velocity'
    vout.units = 'm/s'
    vout.coordinates = "latitude longitude"


    # copy axis from original dataset
    longitude[:] = lonNew[:]
    latitude[:] = latNew[:]
    uout[:, :] = u[:, :]
    vout[:, :] = v[:, :]

    # close files
    ncout.close()
    # print(tracemalloc.get_traced_memory())
    # tracemalloc.stop()


latOld = latNC # np.arange(30, 90, 0.08)
lonOld = lonNC # np.arange(0, 360, 0.08)
latNew = np.arange(30, 90, 0.04)
lonNew = np.arange(-180, 180, 0.04)
#
# Regrid (GNT needs same lat & lon resolution)
iDepth100 = np.argmin(np.abs(depths-100))  # index of depth=100 m
iDepth1000 = np.argmin(np.abs(depths-1000))  # index of depth=1000 m
uNew = np.empty((iDepth1000+1, len(latNew), len(lonNew))) * np.nan
vNew = np.empty((iDepth1000+1, len(latNew), len(lonNew))) * np.nan
#


def interp(k):
    uz = u[k]
    vz = v[k]
    #
    # For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    #
    fu = interpolate.interp2d(lonOld, latOld, uz, kind='linear')
    fv = interpolate.interp2d(lonOld, latOld, vz, kind='linear')
    #
    uNew = fu(lonNew, latNew)
    vNew = fv(lonNew, latNew)
    return k, uNew, vNew


for k, uk, vk in multiprocessing.Pool().map(interp, np.arange(len(depths[:iDepth1000+1]))):
    uNew[k, :, :] = uk[:, :]
    vNew[k, :, :] = vk[:, :]

del k, uk, vk


# Turn land into nan
uNew[(uNew == 0) & (vNew == 0)] = np.nan
vNew[np.isnan(uNew)] = np.nan


# Average from 100 to 1000 m depth
uZavg = np.nanmean(uNew[iDepth100:iDepth1000+2, :, :], axis=0)
vZavg = np.nanmean(vNew[iDepth100:iDepth1000+2, :, :], axis=0)
# Where depth<100, average from 0 to 100
uBelow100Avg = np.nanmean(uNew[:iDepth100+1, :, :], axis=0)
uZavg[np.isnan(uZavg)] = uBelow100Avg[np.isnan(uZavg)]
vBelow100Avg = np.nanmean(vNew[:iDepth100+1, :, :], axis=0)
vZavg[np.isnan(vZavg)] = vBelow100Avg[np.isnan(vZavg)]
# del uNew, vNew, uBelow100Avg, vBelow100Avg

writeNC('avgDepth',uZavg,vZavg)


##  Write surface values
writeNC('surface',uNew[0,:,:],vNew[0,:,:])
