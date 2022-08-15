#!/bin/bash

#
# VARIABLES
#

# Path
export WORK_PATH=`pwd`
export SOFTWARES_PATH=/data/softwares
export WWW_PATH=/data/www

# Color
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_PLAIN='\033[0m'

#
# FUNCTIONS
#

# Usage:
#   deploy_service service_name service_file
# Arguments:
#   service_name
#   service_file
deploy_service() {
    read -t 60 -n9 -p "Would you want to deploy ${1}?(y/n) " result_for_choosing
    if [[ $result_for_choosing =~ y|Y ]]; then
        ${2}
    fi
}

#
# BASIC
#

# change apt sources to Aliyun Source
read -t 60 -n9 -p "Would you want to change the apt sources to Aliyun Source?(y/n) " result_for_choosing
if [[ $result_for_choosing =~ y|Y && `cat /etc/apt/sources.list | grep aliyun` = '' ]]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    cp $WORK_PATH/config/sources.list /etc/apt/
fi

# update software source
apt update

# upgrade local softwares
read -t 60 -n9 -p "Would you want to upgrade local softwares?(y/n) " result_for_choosing
if [[ $result_for_choosing =~ y|Y ]]; then
    apt upgrade -y
fi

# install Chinese language package
read -t 60 -n9 -p "Would you want to install Chinese language package?(y/n) " result_for_choosing
if [[ $result_for_choosing =~ y|Y ]]; then
    apt install -y language-pack-zh-hans
fi

# modify system timezone to Asia/Shanghai
read -t 60 -n9 -p "Would you want to modify system timezone to Asia/Shanghai?(y/n) " result_for_choosing
if [[ $result_for_choosing =~ y|Y ]]; then
    if [[ ! `timedatectl | grep "Time zone"` =~ 'Asia/Shanghai' ]]; then
        timedatectl set-timezone Asia/Shanghai
    fi
fi

# check BBR and enabled it
read -t 60 -n9 -p "Would you want to enable BBR?(y/n) " result_for_choosing
if [[ $result_for_choosing =~ y|Y ]]; then
    result_for_bbr_in_kernel=`sysctl net.ipv4.tcp_available_congestion_control | grep bbr`
    result_for_bbr_in_mod=`lsmod | grep bbr`
    if [[ "$result_for_bbr_in_kernel" = '' ]]; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi
    if [[ "$result_for_bbr_in_mod" = '' ]]; then
        sysctl -p
    fi
fi

# install some tools for compiling and installing from source code
apt install -y build-essential libtool

# create basic directory
mkdir -p $SOFTWARES_PATH $WWW_PATH

#
# SERVICES
#

# deploy services
for service_file in $WORK_PATH/services/*; do
    if [[ -x $service_file ]]; then
        service_name=`basename $service_file`
        service_name=${service_name%.*}
        deploy_service $service_name $service_file
    fi
done

#
# END
#

apt autoremove -y
