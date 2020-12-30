#!/usr/bin/env bash
. utils.sh
clear
prnt "Manage etcd states"
declare -A stateActions
stateActions+=(['Quit']='quit')
stateActions+=(['Save the current running etcd state']='save')
stateActions+=(['Delete all or selected states']='delete')
stateActions+=(['Restore a saved state']='restore')
stateActions+=(['List the saved states']='list')
stateActions+=(['Restore last external etcd state']='last-external')
stateActions+=(['Restore last embedded etcd state']='last-embedded')
stateActions+=(['System pods states']='pod-state')
stateActions+=(['Current cluster state']='cluster-state')
stateActions+=(['Restart kubernetes runtime']='restart-runtime')
stateActions+=(['Refresh view']='refresh-view')
stateActions+=(['Snapshot view']='snapshot-view')
stateActions+=(['Cluster view']='cluster-view')
re="^[0-9]+$"
PS3=$'\e[01;32mSelection: \e[0m'
select option in "${!stateActions[@]}"; do

  if ! [[ "$REPLY" =~ $re ]] || [ "$REPLY" -gt 13 -o "$REPLY" -lt 1 ]; then
    err "Invalid selection!"
  else
    case "${stateActions[$option]}" in
      list)
        list_saved_states
        ;;
      save)
        prnt "Saving state - enter file name"
        read fileName
        . save-state.sh $fileName
        ;;
      delete)
        if saved_state_exists; then
          PS3="Deleting states - choose option: "
          delete_options=(All Some Back)
          select delete_option in "${delete_options[@]}"; do
            case "$delete_option" in
              All)
                echo "Deleting all saved states"
                delete_saved_states -a
                break
                ;;
              Some)
                echo "Type in file names - blank line to complete"
                rm -f /tmp/state_deletions.tmp
                while read line; do
                  [ -z "$line" ] && break
                  echo "$line" >>/tmp/state_deletions.tmp
                done
                selected_for_deletions=$(cat /tmp/state_deletions.tmp | tr "\n" " " | xargs)
                delete_saved_states $selected_for_deletions
                rm -f /tmp/state_deletions.tmp
                break
                ;;
              Back)
                break
                ;;
            esac
          done
          echo ""
          PS3=$'\e[01;32mSelection: \e[0m'
        else
          err "No saaved state to delete"
        fi
        ;;
      restore)
        if saved_state_exists; then
          prnt "Restoring state - enter state name: "
          read fileName
          if saved_state_exists $fileName; then
            . restore-state.sh $fileName
          fi
        else
          err "No saved state to restore!"
        fi
        ;;
      last-embedded)
        prnt "Restoring last embedded state"
        . restore-state.sh embedded-up
        ;;
      last-external)
        prnt "Restoring last external state"
        . restore-state.sh external-up
        ;;
      cluster-state)
        . cs.sh
        ;;
      pod-state)
        . checks/system-pod-state.sh
        ;;
      restart-runtime)
        PS3=$'\e[01;32mRestarting k8s runtime - choose option: \e[0m'
        restart_options=("Auto-detect kube nodes" "Enter ips" "Back")
        select restart_option in "${restart_options[@]}"; do
          case "$REPLY" in
            1)
              . restart-runtime.sh
              break
              ;;
            2)
              echo "Type in the kube node IPs - blank line to complete: "
              rm -f /tmp/kube_ips.tmp
              while read line; do
                # break if the line is empty
                [ -z "$line" ] && break
                echo "$line" >>/tmp/kube_ips.tmp
              done
              kube_ips=$(cat /tmp/kube_ips.tmp | tr "\n" " " | xargs)
              . restart-runtime.sh $kube_ips
              rm -f /tmp/kube_ips.tmp
              break
              ;;
            3)
              break
              ;;
          esac
        done
        echo ""
        PS3=$'\e[01;32mSelection: \e[0m'
        ;;
      refresh-view)
        . states.sh && exit 0
        ;;
      snapshot-view)
        . snapshots.sh && exit 0
        ;;
      quit)
        prnt "quit"
        break
        ;;
      cluster-view)
        err "Cluster view not enabled!"
        ;;
    esac
  fi
done