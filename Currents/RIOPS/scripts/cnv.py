import numpy as np
from netCDF4 import Dataset
import numpy as np
import sys
from multiprocessing import Pool
from scipy import interpolate
import matplotlib.pyplot as plt
import png
from datetime import datetime, timedelta


date = sys.argv[1]
hr = int(sys.argv[2])

if (hr<24):
    dateSave = date
    hrSave = hr
elif (hr<48):
    dateSave = datetime.strftime(datetime.strptime(date, "%Y%m%d") + timedelta(days=1), "%Y%m%d")
    hrSave = hr - 24
elif (hr<72):
    dateSave = datetime.strftime(datetime.strptime(date, "%Y%m%d") + timedelta(days=2), "%Y%m%d")
    hrSave = hr - 48


depthRanges = [[0,10],[10,50],[50,100],[100,200],[200,500],[500,1000],[1000,1500],[1500,2000],[50,20000]]
missingValue = 1e+20


##  U
ncU = Dataset("CMC_RIOPS_ux_%s_%03d.nc" % (date, hr),'r')
ux = ncU.variables['vozocrtx'][0].data
ux[ux==missingValue] = np.nan


##  V
ncV = Dataset("CMC_RIOPS_vy_%s_%03d.nc" % (date, hr),'r')
vy = ncV.variables['vomecrty'][0].data
vy[vy==missingValue] = np.nan


##  latitude, longitude, depth
lon = np.arange(0,360,0.08)
lat = np.arange(-90,90.08,0.08)
depths = ncU.variables['depth'][:].data


##  ux,vx -> u,v
## longitude[i,j]<260:   theta = (longitude[i,j] + 100) * np.pi/180
## longitude[i,j]>=260:  theta = (longitude[i,j] - 260) * np.pi/180
theta = lon * np.pi/180
theta[lon<260] += 100*np.pi/180
theta[lon>=260] -= 260*np.pi/180
u = ux*np.cos(theta) + vy*np.sin(theta)  ## lat: 30 - 90  (750 points)
v = -ux*np.sin(theta) + vy*np.cos(theta) ## ...

##  Global array for jpg (lat: -85 - 85)
lat = np.arange(-85,85.08,0.08)
uGlob = np.empty((len(depths), 2126,4500))
vGlob = np.empty((len(depths), 2126,4500))

uGlob[:,1438:,:] = u[:,:688,:]  ## lat: -85 - 85
vGlob[:,1438:,:] = v[:,:688,:]  ## ...


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), 4500)
yy = np.linspace(np.min(y), np.max(y), 2001)


##  Fixed min/max values for all levels and times
uMin = -3.
uMax = 3.
vMin = -3.
vMax = 3.


def saveImage(depthRange):
    uz = np.nanmean(uGlob[np.bitwise_and(depths>=depthRange[0],depths<depthRange[1]),:len(lat),:], axis=0)
    vz = np.nanmean(vGlob[np.bitwise_and(depths>=depthRange[0],depths<depthRange[1]),:len(lat),:], axis=0)
    #
    ##  For interpolation, NaN is not accepted
    uz[np.isnan(uz)] = 0
    vz[np.isnan(vz)] = 0
    #
    fu = interpolate.interp2d(x, y, uz, kind='cubic')
    fv = interpolate.interp2d(x, y, vz, kind='cubic')
    #
    uNew = fu(xx, yy)
    vNew = fv(xx, yy)
    #
    #
    ##  Normalize values
    uNew = (65535*(uNew-uMin)/(uMax-uMin)).astype(np.uint16)
    vNew = (65535*(vNew-vMin)/(vMax-vMin)).astype(np.uint16)
    #
    #
    ##  Rearrange u and v to lon: -180 to 180
    # uNew = np.concatenate((uNew[:,2250:], uNew[:,:2250]), axis=1)
    # vNew = np.concatenate((vNew[:,2250:], vNew[:,:2250]), axis=1)
    #
    #
    ##  Save image
    img = np.empty((2001,4500,3), dtype=np.uint16)  ##  lat,lon res = 0.08 deg ; covering from 80S to 80N
    img[:,:,0] = uNew[:,:]  ##  Fill from 30N to 80N
    img[:,:,1] = vNew[:,:]  ##  ...
    img[:,:,2] = 0
    #
    with open('../png/RIOPS_Currents_%s_%02d_%04d-%04d.png' % (dateSave, hrSave, depthRange[0], depthRange[1]), 'wb') as f:
        writer = png.Writer(width=img.shape[1], height=img.shape[0], bitdepth=16, greyscale=False)
        # Convert img to the Python list of lists expected by the png writer
        img2list = np.flipud(img).reshape(-1, img.shape[1]*img.shape[2]).tolist()
        writer.write(f, img2list)


# plt.imshow(img)
# plt.show()


with Pool(10) as p:
    p.map(saveImage, depthRanges)


#############################################
##  Average depth for forecast/hindcast files
##  Only if hr<24
if (hr<24):
    lon = np.arange(-180,180,0.08)
    lat = np.arange(30,90,0.08)
    #
    #
    ##  Average from 100 to 1000 m depth
    uZavg = np.nanmean(u[(depths>=100) & (depths<=1000),:,:], axis=0)
    vZavg = np.nanmean(v[(depths>=100) & (depths<=1000),:,:], axis=0)
    ##  Where depth<100, average from 0 to 100
    uBelow100Avg = np.nanmean(u[(depths<100),:,:], axis=0)
    uZavg[np.isnan(uZavg)] = uBelow100Avg[np.isnan(uZavg)]
    vBelow100Avg = np.nanmean(v[(depths<100),:,:], axis=0)
    vZavg[np.isnan(vZavg)] = vBelow100Avg[np.isnan(vZavg)]
    #
    #
    ##  Write netCDF
    # open a netCDF file to write
    fileName = "RIOPS_Currents_avgDepth_%s_%02d.nc" % (date, hr)
    ncout = Dataset(fileName, 'w', format='NETCDF4')
    #
    #
    # define axis size
    ncout.createDimension('x', len(lon))
    ncout.createDimension('y', len(lat))
    #
    # create latitude axis
    latitude = ncout.createVariable('latitude', 'double', ('y'))
    latitude.standard_name = 'latitude'
    latitude.long_name = 'latitude'
    latitude.units = 'degrees_north'
    latitude.axis = 'Y'
    #
    # create longitude axis
    longitude = ncout.createVariable('longitude', 'double', ('x'))
    longitude.standard_name = 'longitude'
    longitude.long_name = 'longitude'
    longitude.units = 'degrees_east'
    longitude.axis = 'X'
    #
    # create variable array
    uout = ncout.createVariable('u', 'double', ('y', 'x'))
    uout.long_name = 'zonal velocity'
    uout.units = 'm/s'
    uout.coordinates = "latitude longitude"
    #
    vout = ncout.createVariable('v', 'double', ('y', 'x'))
    vout.long_name = 'meridional velocity'
    vout.units = 'm/s'
    vout.coordinates = "latitude longitude"
    #
    #
    # copy axis from original dataset
    longitude[:] = lon[:]
    latitude[:] = lat[:]
    uout[:,:] = uZavg[:,:]
    vout[:,:] = vZavg[:,:]
    #
    # close files
    ncout.close()

