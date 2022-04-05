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


ncFile = Dataset("CMC_gdwps_global_ICEC_SFC_0_latlon0.25x0.25_%s00_P%03d.nc" % (date, hr), 'r')

ice = ncFile.variables['ci'][0].data

iceMin = 0.
iceMax = 1.

ice[ice<0] = iceMin  ##  For interpolation, NaN is not accepted

##  latitude and longitude
lat = np.arange(-80,80.01,0.25)
lon = np.arange(-180,180,0.25)
ice = ice[40:681]  ##  Limit lat range (80S - 80N)

##  Switch west and east
tmp = np.copy(ice[:,:720])
ice[:,:720] = ice[:,720:]
ice[:,720:] = tmp


##  Mercator
R = 6378137
x = R * lon * np.pi/180.
y = R * np.log( np.tan(np.pi/4 + lat*np.pi/180/2) )


##  For interpolation
xx = np.linspace(np.min(x), np.max(x), 36000)  ## 0.01 deg
yy = np.linspace(np.min(y), np.max(y), 16000)  ## 0.01 deg


f = interpolate.interp2d(x, y, ice, kind='linear')
iceNew = f(xx, yy)
iceNewRounded = np.round(iceNew, 2)
iceNewRounded[iceNewRounded>iceMax] = iceMax
iceNewRounded[iceNewRounded<iceMin] = iceMin
iceNewInt = (100*(iceNewRounded)).astype(np.int)


##  No ice = white
color0  = [Color('white').rgb]

##  Blue range
colors1 = [color.rgb for color in list(Color("#fff").range_to(Color("#00f"), 100))]

##  All ranges
colors = np.array(color0+colors1)
iceColored = 255*colors[iceNewInt]


os.mkdir("../png/CMC_Seaice_%s_%02d/" % (datetime.strftime(dateSave, "%Y%m%d"),hrSave))
for i in np.arange(18):
    ##  Due to the damn Mercator projection:
    j = 0
    for lat1,lat2 in zip(np.arange(-80,80,20),np.arange(-60,100,20)):
        y1 = R * np.log( np.tan(np.pi/4 + lat1*np.pi/180/2) )
        j1 = np.abs(yy-y1).argmin()
        y2 = R * np.log( np.tan(np.pi/4 + lat2*np.pi/180/2) )
        j2 = np.abs(yy-y2).argmin()
        subIce = iceColored[j1:j2, i*2000:(i+1)*2000]
        img2list = np.flipud(subIce).reshape(-1, 3*subIce.shape[1]).astype(np.uint8)
        with open('../png/CMC_Seaice_%s_%02d/CMC_Seaice_%s_%02d_reg%02d-%02d.png' % (datetime.strftime(dateSave, "%Y%m%d"),hrSave,datetime.strftime(dateSave, "%Y%m%d"),hrSave, i,j), 'wb') as f:
            writer = png.Writer(width=subIce.shape[1], height=subIce.shape[0], bitdepth=8, greyscale=False)
            writer.write(f, img2list)
        j += 1


exit()

plt.imshow(sstNew)
plt.show()
