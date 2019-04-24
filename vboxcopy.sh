#!/bin/bash

IFS="
"
LOG="vboxcopy.log"
PID=$$
MNTDIR="/mnt/vboxcopy_${PID}"

function log() {
    echo -e "`date +'%d/%m/%Y %H:%M:%S'` | $1"
    echo -e "`date +'%d/%m/%Y %H:%M:%S'` | $1" >> $LOG
  }

function usage() {
    echo -e "\n $1\n"
    echo -e "./vboxcopy.sh \e[93m--help \e[39m "
    echo -e "./vboxcopy.sh \e[93m--list \e[39m "
    echo -e "./vboxcopy.sh --vm=\e[96m'IT development sql'\e[39m --dest=\e[91m10.20.30.40\e[39m --user=\e[91mroot\e[39m --dir=\e[91m/vmachines\e[39m "
    echo
    exit
}

function list () {
    total=0
    count=0
    for vm in $(vboxmanage list vms); do
         vm_name="$(echo $vm | awk -F\{ '{print $1}' | sed 's/[[:space:]]*$//' | sed 's/\"//g' )"
         vm_log=$(vboxmanage showvminfo "$vm_name" | grep "Log folder" | awk -F: '{print $2}' | sed 's/^[ ]*//g')
         vm_dir=$(dirname "$vm_log")
         vm_size_h=$(du -sh "$vm_dir" | awk '{print $1}')
         vm_size_b=$(du -s "$vm_dir" | awk '{print $1}')
         echo -e "\e[94m $vm_size_h \e[39m " "$vm_name"
         total=$((total+vm_size_b))
         count=$((count+1))
    done
    echo -e "\e[44m $((total / 1024 / 1024))G\e[39m \e[101m TOTAL  ($count)\e[49m"
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
  [ -d "$MNTDIR" ] || mkdir "$MNTDIR"
  if ssh -q  -o BatchMode=yes -o ConnectTimeout=10 $SSHUSER@$HOST exit; then
    if ssh $SSHUSER@$HOST ls "$DIR" > /dev/null; then
      if sshfs -o rw $SSHUSER@$HOST:"$DIR" "$MNTDIR"; then
        log "[ OK ] sshfs mount"
        return 0
      else
        log "[FAIL] mount $USER@$HOST to $MNTDIR"
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
  dst_size=$(ssh $SSHUSER@$HOST df "$DIR" | grep -v Filesystem | awk '{print $4}')

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
            "$vm_dir" "$MNTDIR" >> $LOG

  if [ $? -eq 0 ]; then
    log "[ OK ] copy vm"
    return 0
  else
    log "[FAIL] copy vm"
    return 1
  fi
}

function check_copy () {
    vm_log=$(vboxmanage showvminfo "$VM" | grep "Log folder" | awk -F: '{print $2}' | sed 's/^[ ]*//g')
    vm_name=$(vboxmanage showvminfo "$VM" | grep "Name:" | awk -F: '{print $2}' | sed 's/^[ ]*//g')
    vm_dir=$(dirname "$vm_log")

    cd "$vm_dir"
    find . -type f -exec md5sum {} + | sort -k 2 > "/tmp/src_vm"
    cd "$MNTDIR/${vm_name}"
    find . -type f -exec md5sum {} + | sort -k 2 > "/tmp/dst_vm"
    cd ~

    if diff -u "/tmp/src_vm" "/tmp/dst_vm"; then
      log "[ OK ] destination checksum"
      return 0
    else
      log "[FAIL] destination checksum"
      return 1
    fi
}

function umount_ssh () {
  if umount "$MNTDIR"; then
    if rmdir "$MNTDIR"; then
      log "[ OK ] sshfs umount"
      return 0
    else
      log "[FAIL] to remove mount dir. Not empty"
      return 1
    fi
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
  log "USER : $SSHUSER"
  log ""

  if close_vm; then
    if mount_ssh; then
      if check_space; then
        copy_vm
        check_copy
        umount_ssh
        start_vm
      fi
    fi
  fi
}


commands=(rsync find rmdir du date umount ssh sshfs vboxmanage)
for command in "${commands[@]}"
do
    if ! command -v ${command} > /dev/null; then
        echo -e "Command \e[96m$command\e[39m not found"

        exit
    fi
done


while [ "$1" != "" ]; do
  PARAM=`echo "$1" | awk -F= '{print $1}'`
  VALUE=`echo "$1" | awk -F= '{print $2}'`

  case $PARAM in
    --help)
      usage
      exit 1
      ;;
    --list)
      list
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
      SSHUSER=$VALUE
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done


[ -z "$VM" ] && usage "missing \e[91m'--vm'\e[39m option"
[ -z "$HOST" ] && usage "missing \e[91m'--host'\e[39m option"
[ -z "$DIR" ] && usage "missing \e[91m'--dir'\e[39m option"
[ -z "$SSHUSER" ] && usage "missing \e[91m'--user'\e[39m option"

main
