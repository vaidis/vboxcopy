# VBoxCopy
vboxcopy is a simple backup script used with cron to backup virtualbox vm machines  

* the destination host must alrady have the source host's ssh public keys  
* the source vm will power off (soft) before the copy, and will power on after  
* detailed log entries are created for every copy  

## crontab settings
```
0 1 * * * /opt/vboxcopy.sh --vm='Centos 7 admin' --host=10.0.0.1 --dir='/vmachines' --user=root
```

## how it works
The main function describes the workflow of this script  
```
  if close_vm; then
    if mount_ssh; then
      if check_space; then
        copy_vm
        umount_ssh
        start_vm
      fi
    fi
  fi
```
