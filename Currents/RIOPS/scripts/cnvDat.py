import numpy as np
from netCDF4 import Dataset
import numpy as np
import sys


# date = sys.argv[1]
# hr = int(sys.argv[2])
# vars = ["vozocrtx", "vomecrty"]
# fileNames = ["CMC_riops_vozocrtx_depth_all_ps5km60N_3h-mean_%s00_P%03d.nc" % (date, hr),
#              "CMC_riops_vomecrty_depth_all_ps5km60N_3h-mean_%s00_P%03d.nc" % (date, hr)]
fileName = "uv_avgDepth_2020-08-12_21.nc"

arrZavg = [np.nan, np.nan]
for i in np.arange(2):
    # fileName = "CMC_riops_%s_depth_all_ps5km60N_3h-mean_%s00_P%03d.nc" % (vars[i], date, hr)
    ncin = Dataset(fileName,'r')
    lon = ncin.variables['longitude'][:].data
    lat = ncin.variables['latitude'][:].data
    u = ncin.variables['u'][:].data
    v = ncin.variables['v'][:].data


iMax, jMax = lat.shape
with open('uv.dat', 'w') as outFile:
    for i in np.arange(iMax):
        for j in np.arange(jMax):
            if (not np.isnan(u[i,j])):
                outFile.write('%10.3f,%10.3f,%10.3f,%10.3f\n' % (lon[i,j],lat[i,j],u[i,j],v[i,j]))
