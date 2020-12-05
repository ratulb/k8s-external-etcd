#!/usr/bin/env bash 
apt update
if  ! which etcd &> /dev/null;
  then
    ETCD_VER="3.4.14"
    echo -e "\e[1;42m Installing etcd $ETCD_VER.\e[0m"
    DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
     wget -q --timestamping ${DOWNLOAD_URL}/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-amd64.tar.gz -O /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz
    rm -rf /tmp/etcd-download-loc
    mkdir /tmp/etcd-download-loc
    tar xzf /tmp/etcd-v${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-loc --strip-components=1
    mv /tmp/etcd-download-loc/etcdctl /usr/local/bin
    mv /tmp/etcd-download-loc/etcd /usr/local/bin
  else
    echo -e "\e[1;42m Etcd already installed.\e[0m"
fi
etcd --version || etcd version
