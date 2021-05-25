#!/bin/bash
ftpLink="https://ncss.hycom.org/thredds/ncss/GLBy0.08/expt_93.0/uv3z?var=water_u&var=water_v&"

HERE=${PWD}


############################################################################

mkdir ${HERE}/nc
cd ${HERE}/nc/

date=$1 ## eg: 20201020

parallel -j 8 "wget -O HYCOM_Currents_${date}_{}_west.nc '${ftpLink}north=85&west=-180&east=0&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertStride=1&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
parallel -j 8 "wget -O HYCOM_Currents_${date}_{}_east.nc '${ftpLink}north=85&west=0&east=180&south=-85&horizStride=1&time=${date}T{}%3A00%3A00Z&vertStride=1&addLatLon=true&accept=netcdf4'" ::: {00..21..3}
