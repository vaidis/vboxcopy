#!/bin/bash

IFS="\n"
LOG="vboxcopy.log"

function log() {
    echo -e "`date +'%d/%m/%Y %H:%M:%S'` | $1"
    echo -e "`date +'%d/%m/%Y %H:%M:%S'` | $1" >> $LOG
  }

function usage () {
    echo
    echo -e "./vmove.sh \e[94mhelp\e[39m"
    echo -e "./vmove.sh \e[94mcheck\e[39m"
    echo -e "./vmove.sh --vm=\e[96m'IT development sql' \e[39m--dest=\e[91m10.20.30.40\e[39m --user=root"
    echo
    exit
}

function close_vm () {
  if vboxmanage showvminfo "$VM" > /dev/null; then
    if vboxmanage list runningvms | grep "$VM" > /dev/null; then
      if vboxmanage controlvm "$VM" poweroff soft -q 2> /dev/null; then
        log "[ OK ] power off vm"
        return 0
      fi
    else
      log "[ OK ] vm is already powered off"
      return 0
    fi
  else
    log "[FAIL] vm not found"
    return 1
  fi
}

function mount_ssh() {
  [ -d /mnt/vmove ] || mkdir /mnt/vmove
  if ssh -q  -o BatchMode=yes -o ConnectTimeout=10 $USER@$HOST exit; then
    if ssh $USER@$HOST ls "$DIR" > /dev/null; then
      if sshfs -o rw $USER@$HOST:"$DIR" /mnt/vmove; then
        log "[ OK ] sshfs mount"
        return 0
      else
        log "[FAIL] mount $USER@$HOST to /mnt/vmove"
        return 1
      fi
    else
      log "[FAIL] remote dir $DIR not found"
      return 1
    fi
  else
    log "[FAIL] ssh $USER@$HOST"
    return 1
  fi
}

function check_space () {
  vm_log=$(vboxmanage showvminfo "$VM" | grep "Log folder" | awk -F: '{print $2}' | sed 's/^[ ]*//g')
  vm_dir=$(dirname "$vm_log")
  src_size=$(du -s "$vm_dir" | awk '{print $1}')
  dst_size=$(ssh root@10.0.31.221 df "$DIR" | grep -v Filesystem | awk '{print $4}')

  log "source vm size: $src_size"
  log "remote available size: $dst_size"

  if [ "$dst_size" -gt "$src_size" ]; then
    log "[ OK ] enought available space"
    return 0
  else
    log "[FAIL] not enought available space"
    return 1
  fi
}

function copy_vm () {
  rsync -av -e "ssh -T -c arcfour -o Compression=no -x" \
            --stats \
            --temp-dir=/tmp \
            --human-readable \
            --no-owner \
            --no-group \
            "$vm_dir" /mnt/vmove >> $LOG

  if [ $? -eq 0 ]; then
    log "[ OK ] copy vm"
    return 0
  else
    log "[FAIL] copy vm"
    return 1
  fi
}

function umount_ssh () {
  if umount /mnt/vmove; then
    log "[ OK ] sshfs umount"
    return 0
  else
    log "[FAIL] sshfs umount"
    return 1
  fi
}

function start_vm () {
  if vboxmanage startvm "$VM" --type headless > /dev/null; then
    log "[ OK ] start vm"
    return 0
  else
    log "[FAIL] start vm"
    return 1
  fi
}

function main () {
  log ""
  log "-------- START VM COPY ------"
  log "VM   : $VM"
  log "HOST : $HOST"
  log "DIR  : $DIR"
  log "USER : $USER"
  log ""

  if close_vm; then
    if mount_ssh; then
      if check_space; then
        copy_vm
        umount_ssh
        start_vm
      fi
    fi
  fi
}


while [ "$1" != "" ]; do
  PARAM=`echo "$1" | awk -F= '{print $1}'`
  VALUE=`echo "$1" | awk -F= '{print $2}'`

  case $PARAM in
    --help)
      usage
      exit 1
      ;;
    --vm)
      VM=$VALUE
      ;;
    --host)
      HOST=$VALUE
      ;;
    --dir)
      DIR=$VALUE
      ;;
    --user)
      USER=$VALUE
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done

main
