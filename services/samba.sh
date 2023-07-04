#!/bin/bash

apt install -y samba

echo "/etc/samba/smb.conf example:
[data]
    comment = Samba Data
    path = /data
    browsable = yes
    guest ok = yes
    read only = no
then, restart service: systemctl restart smbd"
