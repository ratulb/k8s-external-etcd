ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/$(hostname)-server.crt --key=/etc/kubernetes/pki/etcd/$(hostname)-server.key --endpoints=https://$(hostname -i):2379  member list
