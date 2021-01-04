#!/usr/bin/env bash
. utils.sh
command_exists kubectl
unset cluster_state
unset cluster_desc
if can_ping_ip $master_ip; then
  if can_access_ip $master_ip; then
    if [ ! -z "$debug" ]; then
      kubectl cluster-info --request-timeout "5s"
    else
      kubectl cluster-info --request-timeout "5s" &>/dev/null
    fi

    cluster_up=$?

    if [ "$this_host_ip" = "$master_ip" ]; then
      ls /etc/kubernetes/manifests/etcd.yaml &>/dev/null
    else
      . execute-command-remote.sh $master_ip ls /etc/kubernetes/manifests/etcd.yaml &>/dev/null
    fi

    etcd_yaml_present=$?

    if [ "$cluster_up" = 0 -a "$etcd_yaml_present" = 0 ]; then
      state_desc="Cluster is running on embedded etcd"
      prnt "$state_desc"
      export $state_desc
      export cluster_state=embedded-up
      debug "cluster state: $cluster_state"

    fi

    if [ "$cluster_up" = 0 -a "$etcd_yaml_present" != 0 ]; then
      state_desc="Cluster is running on external etcd"
      prnt "$state_desc"
      export $state_desc
      export cluster_state=external-up
      debug "cluster state: $cluster_state"
    fi

    if [ "$cluster_up" != 0 -a "$etcd_yaml_present" = 0 ]; then
      state_desc="Cluster not runnig but configured for embedded etcd"
      err "$state_desc"
      export $state_desc
      export cluster_state=emdown
      debug "cluster state: $cluster_state"
    fi

    if [ "$cluster_up" != 0 -a "$etcd_yaml_present" != 0 ]; then
      state_desc="Cluster not runnig and etcd configuration is missing"
      err "$state_desc"
      export $state_desc
      export cluster_state=ukdown
      debug "cluster state: $cluster_state"
    fi
  else
    err "Can not access $master - wrong master or system has not been initialized yet."
  fi

else
  err "Could not ping kube cluster master - wrong master($master_ip) or system has not been initialized yet."
fi
