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

sst = np.array(ncFile.variables['water_temp'][0])
##  Do NOT switch here since we want to save 3D rho later
# sst = np.concatenate((sst[:,:,2250:], sst[:,:,:2250]), axis=2) # Switch west and east

sss = np.array(ncFile.variables['salinity'][0])
# sss = np.concatenate((sss[:,:,2250:], sss[:,:,:2250]), axis=2) # Switch west and east

latNC = ncFile.variables['lat'][:].data

lonNC = ncFile.variables['lon'][:].data
lonNC = np.concatenate((lonNC[2250:], lonNC[:2250])) # Switch west and east
lonNC[lonNC > 180] -= 360

depthNC = ncFile.variables['depth'][:].data


##  Calculate Density
##  https://link.springer.com/content/pdf/bbm%3A978-3-319-18908-6%2F1.pdf
##  temperature range: 0 - 40
##  salinity range: 0 - 42
sst[sst<0] = np.nan

a0 = 999.842594
a1 = 6.793953 * 10**-2
a2 = -9.095290*10**-3
a3 = 1.001685*10**-4
a4 = -1.120083*10**-6
a5 = 6.536332*10**-9
rho_SMOW = a0 + a1*sst + a2*sst**2 + a3*sst**3 + a4*sst**4 + a5*sst**5

b0 = 8.2449*10**-1
b1 = -4.0899*10**-3
b2 = 7.6438*10**-5
b3 = -8.2467*10**-7
b4 = 5.3875*10**-9
B1 = b0 + b1*sst + b2*sst**2 + b3*sst**3 + b4*sst**4

c0 = -5.7246*10**-3
c1 = 1.0227*10**-4
c2 = -1.6546*10**-6
C1 = c0 + c1*sst + c2*sst**2

d0 = 4.8314*10**-4

rho = rho_SMOW + B1*sss + C1*sss**1.5 + d0*sss**2


# Mercator
R = 6378137
xNC = R * lonNC * np.pi/180.
yNC = R * np.log(np.tan(np.pi/4 + latNC*np.pi/180/2))


# For interpolation
# xx = np.linspace(np.min(x), np.max(x), len(lonTile))
# yy = np.linspace(np.min(y), np.max(y), len(latTile))


# Fixed min/max values for all levels and times
ssdMin = 1020
ssdMax = 1030


# For interpolation, NaN is not accepted
ssd = rho[0,:,:]
ssd = np.concatenate((ssd[:,2250:], ssd[:,:2250]), axis=1) # Switch west and east
ssd[np.isnan(ssd)] = -9999  ##  Since we want to keep ssdMin's
f = interpolate.interp2d(xNC, yNC, ssd, kind='linear')


###################################################################
###########################  FUNCTIONS  ###########################


def xMercator(lon):
    return R * lon * np.pi/180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi/4 + lat*np.pi/180/2))


def saveImg(i, j):
    devNull = os.system('mkdir -p %s/tiles/HYCOM_SSD_%s_%02d/%d/%d' %
                        (path, date, hr, zoom, i))
    ssdNew = f(xTile[i*tileSize: (i+1)*tileSize],
               yTile[j * tileSize:(j+1) * tileSize])
    ssdNew[ssdNew > ssdMax] = ssdMax
    ssdNew[ssdNew < ssdMin] = np.nan
    # sstNew[sstNew < sstMin] = sstMin
    if(np.isnan(np.nanmax(ssdNew))):
        return
    else:
        # Coloring
        ssdNewRounded = np.round(ssdNew, 1)
        ssdNewInt = (10*(ssdNewRounded-ssdMin)).astype(np.int16)
        # sstNewInt[sstNewInt < 0] = 0
        # sstNewInt[sstNewInt > 10 *
        #           (sstMax-sstMin)] = 10*(sstMax-sstMin)
        ssdColored = colors[ssdNewInt]
        # Saving
        imageio.imwrite('%s/tiles/HYCOM_SSD_%s_%02d/%d/%d/%d.png' % (path, date, hr,
                                                                     zoom, i, 2**zoom-j-1), np.flipud(ssdColored).astype(np.uint8))


def colorRange(color1, color2, n):
    colors = []
    for r,g,b,a in zip(np.linspace(color1[0],color2[0],n) ,np.linspace(color1[1],color2[1],n) ,np.linspace(color1[2],color2[2], n),np.linspace(color1[3],color2[3], n)):
        colors.append((r,g,b,a))
    return colors


##  no data = transparent
color0  = [(0,0,0,0)]
colors1 = colorRange([102,255,255,255],[0,0,153,255],100)

##  All ranges
colors = np.array(color0+colors1)


def saveTile():
    global zoom, ssdNew
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
        iters = np.array(np.meshgrid(np.arange(2**zoom),
                                     np.arange(2**zoom))).T.reshape(-1, 2)
        #
        poolSize = min(len(iters), 32)
        with multiprocessing.Pool(poolSize) as p:
            p.starmap(saveImg, iters)


saveTile()
exit()
    
#################################################
##  Save 3D rho as nc (OPASS)
fileName = "avg/HYCOM_rho_%s_%02d.nc" % (date, hr)
ncout = Dataset(fileName, 'w', format='NETCDF4')

# define axis size
ncout.createDimension('latitude', len(latNC))
ncout.createDimension('longitude', len(lonNC))
ncout.createDimension('depth', len(depthNC))

# create latitude axis
latitude = ncout.createVariable('latitude', 'double', ('latitude'))
latitude.standard_name = 'latitude'
latitude.long_name = 'latitude'
latitude.units = 'degrees_north'
latitude.axis = 'Y'

# create longitude axis
longitude = ncout.createVariable('longitude', 'double', ('longitude'))
longitude.standard_name = 'longitude'
longitude.long_name = 'longitude'
longitude.units = 'degrees_east'
longitude.axis = 'X'

# create depth axis
depth = ncout.createVariable('depth', 'double', ('depth'))
depth.standard_name = 'depth'
depth.long_name = 'depth'
depth.units = 'm'
depth.axis = 'Z'

# create variable array
rhoOut = ncout.createVariable('rho', 'double', ('depth', 'latitude', 'longitude'))
rhoOut.long_name = 'Density'
rhoOut.units = 'kg/m3'
rhoOut.coordinates = "depth latitude longitude"

# Reread coordinates to match original file
latNC = ncFile.variables['lat'][:].data
lonNC = ncFile.variables['lon'][:].data
depthNC = ncFile.variables['depth'][:].data

# Filling with date
longitude[:] = lonNC[:]
latitude[:] = latNC[:]
depth[:] = depthNC[:]
rhoOut[:, :, :] = rho[:,:,:]

# close files
ncout.close()
