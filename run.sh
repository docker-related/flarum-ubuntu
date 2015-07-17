#!/bin/bash

stop_service()
{
# ps aux | grep "lxdm.*-d" | grep -v grep | awk {'print $2'} | while read i ; do kill -9 ${i}; done
for sys_service in nginx mysql php5-fpm; do service ${sys_service} stop; done
}

initialize()
{
if
[ -n "$USER_NAME" ]
then
result=0 && for name in $(cat /etc/passwd | cut -d ":" -f1)
do
[ "$USER_NAME" = "${name}" ] && result=$(expr $result + 1) && break
done
[ $result -ne 0 ] && USER_NAME=notroot
else
USER_NAME=notroot
fi
[ -n "$USER_PASSWORD" ] || USER_PASSWORD="notroot"

useradd --create-home --shell /bin/bash --user-group --groups adm,sudo,www-data $USER_NAME

passwd $USER_NAME <<EOF >/dev/null 2>&1
$USER_PASSWORD
$USER_PASSWORD
EOF
/install.sh
}
mysql_start()
{
times=0
while true;do service mysql start;sleep 3;time=$(expr $times + 1); [ $times -ge 10 ] && break ;ps aux |grep mysqld ;pidof mysqld && break;done
}
nginx_start()
{
times=0
while true;do service nginx start;sleep 3;time=$(expr $times + 1); [ $times -ge 10 ] && break ;ps aux | grep nginx;pidof nginx && break;done
}
php_start()
{
times=0
while true;do service php5-fpm start;sleep 3;time=$(expr $times + 1); [ $times -ge 10 ] && break ;ps aux |grep php-fpm ;pidof php5-fpm && break;done
}
username=$(ls /home/ | sed -n 1p)
if
[ -n "$username" ]
then
USER_NAME="$username"
which beanstalkd && service beanstalkd start
which mysqld && mysql_start
which php && php_start
which nginx && nginx_start
else
initialize
cat <<EOF
username: $USER_NAME
password: $USER_PASSWORD
Initialize Finished.Have Fun.
EOF
my_id=$$
ps aux | grep -vE "grep|^USER.*PID" | awk '{print $2}' | grep -v "^$my_id$" |while read pid
do
kill -9 ${pid} 2>/dev/null
done
exit 0
fi


# su $USER_NAME <<EOF
# EOF

# test
# useradd --create-home --shell /bin/bash --user-group --groups adm,sudo,www-data notroot
# passwd notroot <<EOF >/dev/null 2>&1
# notroot
# notroot
# EOF
# test

mkdir -p /var/run/sshd
exec /usr/sbin/sshd -D

