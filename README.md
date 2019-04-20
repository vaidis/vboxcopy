# VBoxCopy
vboxcopy is a simple backup script used with cron to backup virtualbox vm machines  

--* the destination host must alrady have the source host's ssh public keys  
--* the source vm will power off (soft) before the copy, and will power on after  
--* detailed log entries are created for every copy  

## crontab settings
```
0 1 * * * /opt/vboxcopy.sh --vm='Centos 7 admin' --host=10.0.0.1 --dir='/vmachines' --user=root
```

