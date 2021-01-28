#!/usr/bin/env bash
. utils.sh
_etcd_ips=$@
for ip in $_etcd_ips; do
  . remove-admitted-node.sh $ip 'embedded'
done
. start-external-etcds.sh $_etcd_ips
. checks/endpoint-liveness-cluster.sh 5 3
for m_ip in $masters; do
  . synch-etcd-endpoints.sh $m_ip
done
