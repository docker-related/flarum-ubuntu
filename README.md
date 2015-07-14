# lxde-vnc-ubuntu
Add simple  VNC password authentication

This is a Bug fix version，Base on offical ubuntu 14.04(trusty) and some of Community code， 100% work.

# Build

docker build --rm -t  docker-related/lxde-vnc-ubuntu lxde-vnc-ubuntu

# Run

# Width ssh & vnc port and 6080 port for web vnc
docker run -d -p 22222:22 -p 6080:6080 -p 6001:6001 -p 5900:5900 -e USER_NAME="myname" -e USER_PASSWORD="mypass" docker-related/lxde-vnc-ubuntu

# With 6080 port for web vnc Only
docker run -d -p 6080:6080 -e USER_NAME="myname" -e USER_PASSWORD="mypass" docker-related/lxde-vnc-ubuntu

# with language support
docker run -d -p 6080:6080 -e USER_NAME="myname" -e USER_PASSWORD="mypass" -e LANG="zh_CN.UTF-8" docker-related/lxde-vnc-ubuntu

if whithout -e USER_NAME="myname" -e USER_PASSWORD="mypass",
will create default Username: user Password: pass.

# VNC Password
[username]@[password]
Like when whithout -e USER_NAME="myname" -e USER_PASSWORD="mypass",
the default password is: myname@mypass
if you want change the password,just change the file /home/[USER_NAME]/.vncpass .


and

docker stop [container_ID]

docker start [container_ID]

Have fun!


