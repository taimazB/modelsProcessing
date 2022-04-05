export HERE=/home/taimaz/Projects/data
cd ${HERE}


function dl(){
    dir=$1
    cd ${HERE}/${dir}
    # echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    bash `ls dl*.sh`
    # echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log
}

if [[ ! -e ${HERE}/.dlInProgress ]]; then
    > ${HERE}/.dlInProgress
    # > ${HERE}/log

    dl Seaice/RIOPS/
    dl MLD/RIOPS/
    dl Chlorophyll/MODIS/
    dl SST/JPLMUR41/
    dl Currents/RIOPS/
    dl Currents/CMC/
    dl Currents/Doppio
    dl Seaice/RTOFS/
    dl SS/RESPS/
    dl Seaice/Barents
    dl SST/Coraltemp  ##  also Seaice/Coraltemp
    dl Currents/Norkyst800m

    rm ${HERE}/.dlInProgress
    # echo "##########  AT REST!" >> ${HERE}/log
fi
