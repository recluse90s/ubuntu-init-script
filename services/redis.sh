#!/bin/bash

# install
apt install -y redis-server

# configure the `supervised` option and restart the service
sed -i 's/^supervised no$/supervised systemd/g' /etc/redis/redis.conf
systemctl restart redis.service
