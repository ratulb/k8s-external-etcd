#!/usr/bin/env bash
. utils.sh

case $cluster_state in
  1)
    if [ $# = 0 ] || [ $1 != '--force' -a $1 != '-f' ]; then
      err "Already on embedded etcd! $0 --force|-f will restore last snapshot."
      exit 1
    else
      prnt "Will restore last snapshot."
    fi
    ;;
  2)
    prnt "Moving from external to embedded etcd."
    . resurrect-embedded-etcd.sh
    ;;
  3 | 4 | *)
    prnt "Will restore last snapshot."
    ;;
esac
