#!/usr/bin/env bash
#
# Simulates mixed workload on HBase using YCSB
# Author: Ashrith (ashrith at cloudwick dot com)
# Date: Wed, 16 2014
# Updated by Jason Temple (jtemple at turnitin dot com)
# Date: Mon Mar 30 2015
#

timestamp=ycsb-`date +"%Y.%m.%d-%T"`
mkdir -p /tmp/hbase/hbase/${timestamp}

#capture everything from stderr and stdout
exec > >(tee /tmp/hbase/${timestamp}/uberlog)
exec 2>&1

OPTIND=1         # Reset in case getopts has been used previously in the shell.
numThreads=1
numOps=0
while getopts "h?t:o:" opt; do
    case "$opt" in
    h|\?)
        echo "ycsb_hbase.sh -t (num threads) -o (num operations)";
        exit 0
        ;;
    t)  numThreads=$OPTARG
        ;;
    o)  numOps=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

#
# You may want to tweak these variables to change the workload's behavior
#
# Number of total rows to insert into hbase
RECORDS_TO_INSERT=100000
# Total operations to perform for a specified workload
TOTAL_OPERATIONS_PER_WORKLOAD=10000
# Throttling (specifies number of operations to perform per sec by ycsb)
OPERATIONS_PER_SEC=$numOps
# Number of threads to use in each workload
THREADS=${numThreads}
# Name of the hbase column family
HBASE_CFM="f1"
# Number of hbase regions to create initially while creating the table in hbase
HBASE_RC=16
# Log file to use
LOG="/tmp/hbase/${timestamp}/hbase_ycsb.log"

#
# NOTE: DON'T CHANGE BEYOND THIS POINT SCRIPT MAY BREAK
#

# Create a table with specfied regions and with one column family
echo "Creating pre-splitted table"
hbase org.apache.hadoop.hbase.util.RegionSplitter usertable HexStringSplit \
  -c ${HBASE_RC} -f ${HBASE_CFM} >> $LOG

for i in a b c d e f;do

   # Load the dataset (no throttling)
   echo "Loading intial dataset for workload ${i}"
   bin/ycsb load hbase -P workloads/workload${i} -p columnfamily=${HBASE_CFM} \
     -p recordcount=${RECORDS_TO_INSERT} \
     -s -threads ${THREADS} >> /tmp/hbase/${timestamp}/hbase_load_${i}.log

   echo
   echo "Simulating workload ${i}"
   echo

   bin/ycsb run hbase -P workloads/workloada -p columnfamily=${HBASE_CFM} \
     -p operationcount=${TOTAL_OPERATIONS_PER_WORKLOAD} \
     -target ${OPERATIONS_PER_SEC} \
     -threads ${THREADS} -s >> /tmp/hbase/${timestamp}/workload${i}.log

   # Delete the table contents
   echo "truncate 'usertable'" | hbase shell

done

# Disable and Drop table existing
echo "Disabling and dropping table"
echo "disable 'usertable'" | hbase shell >> $LOG
echo "drop 'usertable'" | hbase shell >> $LOG

#aggregate results for easier manipulation
for i in a b c d e f;do
  head -10 /tmp/hbase/${timestamp}/workload${i}.log |grep -v YCSB >> /tmp/hbase/${timestamp}/aggResults.${numThreads}Threads.${numOps}Ops
done
