#!/usr/bin/env bash
. utils.sh
unset master_node_addr
unset user_selected
unset master_members
unset masters_from_query
unset masters_from_user
if [[ "$#" -eq 1 ]] && (is_ip $1 || is_host_name_ok $1); then
  master_node_addr=$1
  debug "system-init.sh master_node_addr=$1: $master_node_addr"
else
  master_node_addr=$master_address
  debug "system-init.sh master_node_addr=$master_node_address: $master_node_addr"
fi

prnt "kube-etcd-switch initializing..."
#check ssh acces before we proceed any further
if ! can_access_address $master_node_addr; then
  err "Can not access kubernetes master address $master_node_addr - Not proceeding with system initialization"
  return 1
fi

prnt "Setting up kubectl on $this_host_ip"
. setup-kubectl.sh $master_node_addr
if [ "$?" -ne 0 ]; then
  return 1
fi
j_path='{.items[*].metadata.name}{"\t"}{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
masters_from_query=$(kubectl get nodes --request-timeout "3s" --selector=node-role.kubernetes.io/control-plane -ojsonpath="$j_path")
masters_from_query=$(echo $masters_from_query | xargs)

if [ -z "$masters_from_query" ]; then
  warn "Node $master_node_addr is up - but could not fetch membership information from the cluster"
  OLD_PS3=$PS3
  PS3=$'\e[92mCluster master member(s): \e[0m'
  user_choices=('Master member(s)' 'Cancel')
  select user_choice in "${user_choices[@]}"; do
    unset user_selected
    case "$user_choice" in
      'Master member(s)')
        rm -f /tmp/cluster_master_members.tmp
        unset master_members
        user_selected=members
        prnt "Type in the master member(s) of the cluster - blank line to complete"
        while read line; do
          [ -z "$line" ] && break
          echo "$line" >>/tmp/cluster_master_members.tmp
        done
        if [ -s /tmp/cluster_master_members.tmp ]; then
          master_members=$(cat /tmp/cluster_master_members.tmp | tr "\n" " " | xargs)
          if [ -z "$master_members" ]; then
            err "Invalid entries"
          else
            unset invalids
            for entry in $master_members; do
              if ! is_ip $entry && ! is_host_name_ok $entry; then
                invalids+="$entry "
              fi
            done
            invalids=$(echo $invalids | xargs)
            if [ ! -z "$invalids" ]; then
              err "Master member(s) not valid: $invalids"
            else
              unset invalid_entries
              for me in $master_members; do
                if ! can_access_address $me; then
                  invalid_entries+="$me "
                fi
              done
              invalid_entries=$(echo $invalid_entries | xargs)
              if [ ! -z "$invalid_entries" ]; then
                err "Provided master member(s): $invalid_entries are not accessible"
              else
                #Game begins here
                prnt "Entries are valids: $master_members"
                break
              fi
            fi
          fi
        else
          err "Invalid entries"
        fi
        ;;
      'Cancel')
        user_selected=cancel
        break
        ;;
      *)
        err "Invalid choiice"
        ;;
    esac
  done
  echo ""
  PS3=$OLD_PS3
else
  masters_from_query=$(echo $masters_from_query | xargs | tr " " "\n" | sort -u | tr "\n" " ")
  debug "The master nodes: $masters_from_query"
fi

if [ "$user_selected" = "cancel" ]; then
  warn "System initialization cancelled"
  return 1
fi

if [[ "$user_selected" = "members" ]] && ! [[ -z "$master_members" ]] && [[ -z "$masters_from_query" ]]; then
  debug "master_members $master_members"
  unset m_hosts
  unset m_ips
  for mm in $master_members; do
    if is_ip $mm; then
      m_ips+="$mm "
      if is_address_local $mm; then
        m_ips+="$(hostname) "
      else
        m_ips+="$(quiet=yes remote_cmd $mm hostname) "
      fi
    else
      m_hosts+="$mm "
      if is_address_local $mm; then
        m_hosts+="$(hostname -i) "
      else
        m_hosts+="$(quiet=yes remote_cmd $mm hostname -i) "
      fi
    fi
  done
  masters_from_user=$(echo $m_hosts $m_ips | xargs | tr " " "\n" | sort -u | tr "\n" " ")
  debug "masters_from_user: $masters_from_user"
fi
unset master_ip_and_names

if [ -z "$masters_from_user" ]; then
  master_ip_and_names=$masters_from_query
else
  master_ip_and_names=$masters_from_user
fi

sudo apt update
command_exists fping || apt install -y fping
. install-cfssl.sh
sudo apt install tree -y
sudo apt autoremove -y
sudo apt install -y wget
sed -i "s/#ETCD_VER#/$etcd_version/g" install-etcd.script
sed -i "s|#kube_vault#|$kube_vault|g" archive.script
sed -i "s|#kube_vault#|$kube_vault|g" unarchive.script

sudo mkdir -p $kube_vault/migration-archive
sudo mkdir -p $default_backup_loc
sudo mkdir -p $gendir
sudo rm cs.sh
sudo rm ep.sh
sudo ln -s checks/cluster-state.sh cs.sh
sudo ln -s checks/endpoint-liveness-cluster.sh ep.sh

prnt "Installing etcd on $this_host_ip"
. install-etcd.script

debug "Intialization request: $master_ip_and_names"
debug "Intialization request: $this_host_ip, $this_host_name and $master_node_addr"

if ! [[ "$master_ip_and_names" =~ "$this_host_ip" ]] && ! [[ "$master_ip_and_names" =~ "$this_host_name" ]] && [[ "$master_ip_and_names" =~ "$master_node_addr" ]]; then

  debug "Intialization request - using remote host as master"
  prnt "Copying etcd certs to $this_host_ip"
  sudo mkdir -p /etc/kubernetes/pki/etcd/

  remote_copy $master_node_addr:/etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/

  if [ "$?" -ne 0 ]; then
    err "Could not copy ca.crt from $master_node_addr. System initialization is not complete!"
    return 1
  fi

  remote_copy $master_node_addr:/etc/kubernetes/pki/etcd/ca.key /etc/kubernetes/pki/etcd/

  if [ "$?" -ne 0 ]; then
    err "Could not copy ca.key from $master_node_addr. System initialization is not complete!"
    return 1
  fi
fi
unset _master_ips
for _me in $master_ip_and_names; do
  if is_ip $_me; then
    _master_ips+="$_me "
  fi
done
unset masters_with_names
for ip_addr in $_master_ips; do
  if is_address_local $ip_addr; then
    masters_with_names+="$(hostname):$ip_addr "
  else
    remote_cmd $ip_addr mkdir -p $kube_vault
    masters_with_names+="$(quiet=yes remote_cmd $ip_addr hostname):$ip_addr "
  fi
done
masters_with_names=$(echo $masters_with_names | xargs)
debug "masters_with_names $masters_with_names"
sed -i "s/masters=.*/masters=$masters_with_names/g" setup.conf
read_setup

for m in $_master_ips; do
  if [ "$m" != "$this_host_ip" ]; then
    remote_script $m install-etcd.script
  fi
done

. gen-cert.sh $this_host_name $this_host_ip
cp $gendir/$(hostname){-peer.*,-client.*,-server.*} /etc/kubernetes/pki/etcd/
if [ ! -z "$masters_from_query" ]; then
  kubectl -n kube-system get pod && prnt "\nSystem has been initialized" || "Some problem occured!"
else
  prnt "System has been initialized"
fi
