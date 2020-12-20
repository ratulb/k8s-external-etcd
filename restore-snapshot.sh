#!/usr/bin/env bash
. utils.sh
  if [ "$#" -ne 4 ]; then
    echo "Usage: $0 'snapshot db file' 'data dir' 'intial cluster token' 'IP'"
    exit 1
  fi
  snapshot_file=$1
  data_dir=$2
  initial_cluster_token=$3
  machine_ip=$4

  dress_up_script etcd-restore.script $snapshot_file $data_dir $initial_cluster_token

  cat etcd-restore.script.tmp
  
  if [ "$this_host_ip" = $machine_ip ]; 
    then
      ./etcd-restore.script.tmp
    else
      . execute-script-remote.sh $machine_ip etcd-restore.script.tmp
  fi
  exit_code=$?
  if [ $exit_code != 0 ]; then
    err "Snapshot restore failed!"
    exit $exit_code
  fi
  prnt "Snapshot($snapshot_file) has been applied @$data_dir in machine($machine_ip) successfully"
  #TODO Should we remove etcd-restore.script.tmp
  #rm etcd-restore.script.tmp