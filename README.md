# VBoxCopy
vboxcopy is a simple backup script used with cron to backup virtualbox vm machines  
vboxcopy send vm's to host that has already the ssh keys from the source host  

## crontab settings
```
0 1 * * * /opt/vboxcopy.sh --vm='Centos 7 admin' --host=10.0.0.1 --dir='/vmachines' --user=root
```

