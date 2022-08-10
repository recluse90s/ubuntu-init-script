#!/bin/bash

# install
apt install -y mysql-server

# skip log bin
if [[ `mysql -Bse "show variables like 'log_bin';" | grep OFF` = '' ]]; then
    echo "skip-log-bin" >> /etc/mysql/mysql.conf.d/mysqld.cnf
    systemctl restart mysql
fi

# change the root authentication method to `mysql_native_password`(for old version)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'tmprootpasswd';"
echo -e "[${COLOR_YELLOW}NOTICE${COLOR_PLAIN}] the temp password for root is ${COLOR_YELLOW}tmprootpasswd${COLOR_PLAIN}."

# run the secure script for MySQL
mysql_secure_installation

# change the root authentication method to `auth_socket`(for 8.x version)
read -t 60 -n9 -p "Would you want to change the root authentication method to auth_socket?(y/n) " result_for_choosing
if [[ $result_for_choosing =~ y|Y ]]; then
    mysql -u root -p -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;"
fi
