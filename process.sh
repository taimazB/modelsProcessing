export HERE=/home/taimaz/Projects/data
cd ${HERE}


function process(){
    dir=$1
    cd ${HERE}/${dir}
    # echo -e "`date +%x-%X` \t `pwd`" >> ${HERE}/log
    bash `ls process*.sh`
    # echo -e "`date +%x-%X` \t `pwd` \t DONE" >> ${HERE}/log
}

if [[ ! -e ${HERE}/.processInProgress ]]; then
    > ${HERE}/.processInProgress
    # > ${HERE}/log

    process Seaice/RIOPS/
    process MLD/RIOPS/
    process Chlorophyll/MODIS/
    process SST/JPLMUR41/
    process Currents/RIOPS/
    process Currents/CMC/
    process Currents/Doppio
    process Seaice/RTOFS/
    process SS/RESPS/
    process Seaice/Barents
    process Currents/Barents
    process SST/Coraltemp
    process Seaice/Coraltemp
    process Currents/Norkyst800m
    
    rm ${HERE}/.processInProgress
    # echo "##########  AT REST!" >> ${HERE}/log
fi
