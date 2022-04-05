import numpy as np
from netCDF4 import Dataset
import os
import sys
import png
import matplotlib.pyplot as plt
from scipy import interpolate
from datetime import datetime, timedelta
from colour import Color


date = sys.argv[1]
hr = int(sys.argv[2])

dateSave = datetime.strptime(date, "%Y%m%d")
hrSave = hr
while(hrSave>=24):
    dateSave += timedelta(days=1)
    hrSave -= 24


ncFile = Dataset("CMC_gdwps_global_HTSGW_SFC_0_latlon0.25x0.25_%s00_P%03d.nc" % (date, hr), 'r')

## Significant height of combined wind waves and swell
swh = ncFile.variables['swh'][0].data

swhMin = 0.
swhMax = 10.

swh[swh<0] = swhMin  ##  For interpolation, NaN is not accepted

##  latitude and longitude
##  nc files are already from lat: 80S to 80N
lat = np.arange(-80,80.01,0.25)
lon = np.arange(0,360,0.25)
swh = swh[40:681]  ##  Limit lat range


##  Switch west and east
tmp = np.copy(swh[:,:720])
swh[:,:720] = swh[:,720:]
swh[:,720:] = tmp


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), 36000)  ## 0.01 deg
yy = np.linspace(np.min(y), np.max(y), 16000)  ## 0.01 deg


f = interpolate.interp2d(x, y, swh, kind='linear')
swhNew = f(xx, yy)
swhNewRounded = np.round(swhNew, 1)
swhNewRounded[swhNewRounded>swhMax] = swhMax+.1
swhNewRounded[swhNewRounded<swhMin] = swhMin
swhNewInt = (10*(swhNewRounded)).astype(np.int)


##  Continents = black
color0  = [Color('black').rgb]

##  Blue range
colors1 = [color.rgb for color in list(Color("#039").range_to(Color("#6cf"), 10))]

##  Green range
colors2 = [color.rgb for color in list(Color("#030").range_to(Color("#9f9"), 10))]

##  Yellow range
colors3 = [color.rgb for color in list(Color("#ff0").range_to(Color("#f93"), 30))]

##  Red range
colors4 = [color.rgb for color in list(Color("#f00").range_to(Color("#fcc"), 50))]

##  Above max
color5 = [Color('#fdd').rgb]

##  All ranges
colors = np.array(color0+colors1+colors2+colors3+colors4+color5)
swhColored = 255*colors[swhNewInt]


try:
    os.mkdir("../png/CMC_SWH_%s_%02d/" % (datetime.strftime(dateSave, "%Y%m%d"),hrSave))
except:
    pass

for i in np.arange(18):
    ##  Due to the damn Mercator projection:
    j = 0
    for lat1,lat2 in zip(np.arange(-80,80,20),np.arange(-60,100,20)):
        y1 = R * np.log( np.tan(np.pi/4 + lat1*np.pi/180/2) )
        j1 = np.abs(yy-y1).argmin()
        y2 = R * np.log( np.tan(np.pi/4 + lat2*np.pi/180/2) )
        j2 = np.abs(yy-y2).argmin()
        subSwh = swhColored[j1:j2, i*2000:(i+1)*2000]
        img2list = np.flipud(subSwh).reshape(-1, 3*subSwh.shape[1]).astype(np.uint8)
        with open('../png/CMC_SWH_%s_%02d/CMC_SWH_%s_%02d_reg%02d-%02d.png' % (datetime.strftime(dateSave, "%Y%m%d"),hrSave,datetime.strftime(dateSave, "%Y%m%d"),hrSave, i,j), 'wb') as f:
            writer = png.Writer(width=subSwh.shape[1], height=subSwh.shape[0], bitdepth=8, greyscale=False)
            writer.write(f, img2list)
        j += 1


exit()

plt.imshow(sstNew)
plt.show()
