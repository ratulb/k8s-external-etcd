#!/usr/bin/env bash
. utils.sh
command_exists kubectl
unset cluster_state
unset cluster_desc
if can_ping_address $master_address; then
  if can_access_address $master_address; then
    if [ ! -z "$debug" ]; then
      kubectl cluster-info --request-timeout "3s"
    else
      kubectl cluster-info --request-timeout "3s" &>/dev/null
    fi

    cluster_up=$?

    if [ "$this_host_ip" = "$master_address" ]; then
      ls /etc/kubernetes/manifests/etcd.yaml &>/dev/null
    else
      remote_cmd $master_address ls /etc/kubernetes/manifests/etcd.yaml &>/dev/null
    fi

    etcd_yaml_present=$?

    if [ "$cluster_up" = 0 -a "$etcd_yaml_present" = 0 ]; then
      state_desc="Cluster is running on embedded etcd"
      prnt "$state_desc"
      export $state_desc
      export cluster_state=embedded-up
    fi

    if [ "$cluster_up" = 0 -a "$etcd_yaml_present" != 0 ]; then
      state_desc="Cluster is running on external etcd"
      prnt "$state_desc"
      export $state_desc
      export cluster_state=external-up
    fi

    if [ "$cluster_up" != 0 -a "$etcd_yaml_present" = 0 ]; then
      state_desc="Cluster not runnig but configured for embedded etcd"
      err "$state_desc"
      export $state_desc
      export cluster_state=emdown
    fi

    if [ "$cluster_up" != 0 -a "$etcd_yaml_present" != 0 ]; then
      state_desc="Cluster not runnig and etcd configuration is missing"
      err "$state_desc"
      export $state_desc
      export cluster_state=ukdown
    fi
  else
    err "Can not access $master_address - wrong master or system has not been initialized yet."
  fi

else
  err "Could not ping kube cluster master - wrong master($master_address) or system has not been initialized yet."
fi
read_setup
api_server_pointing_at
if [ -z "$API_SERVER_POINTING_AT" ]; then
  err "No API server etcd endpoint"
else
  prnt "API server is pointing at:"
  prnt "$API_SERVER_POINTING_AT"
fi
if [ -z "$etcd_servers" ]; then
  warn "External etcd endpoints are empty"
else
  prnt "Etcd servers are:"
  prnt "$etcd_servers"
fi
