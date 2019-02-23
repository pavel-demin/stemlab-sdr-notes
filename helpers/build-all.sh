source /opt/Xilinx/Vivado/2018.3/settings64.sh

JOBS=`nproc 2> /dev/null || echo 1`

make -j $JOBS cores

make NAME=led_blinker all

PRJS="sdr_receiver_hpsdr sdr_transceiver_ft8 sdr_transceiver_hpsdr sdr_transceiver_wspr vna"

printf "%s\n" $PRJS | xargs -n 1 -P $JOBS -I {} make NAME={} bit

sudo sh scripts/alpine.sh
