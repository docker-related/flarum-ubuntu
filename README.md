# flarum-ubuntu
visit https://github.com/flarum to learn more about flarum

This is a Bug fix version，Base on offical ubuntu 14.04(trusty) and some of Community code， 100% work.

# Build

docker build --rm -t  docker-related/flarum-ubuntu flarum-ubuntu

# Run

# Width ssh & web port and 80 port for flarum
docker run -d -p 2222:22 -p 80:80 -e USER_NAME="myname" -e USER_PASSWORD="mypass" docker-related/flarum-ubuntu

# With 80 web server port for flarum
docker run -d -p 80:80 -e USER_NAME="myname" -e USER_PASSWORD="mypass" docker-related/flarum-ubuntu

# with language support
docker run -d -p 80:80 -e USER_NAME="myname" -e USER_PASSWORD="mypass" -e LANG="zh_CN.UTF-8" docker-related/flarum-ubuntu

if whithout -e USER_NAME="myname" -e USER_PASSWORD="mypass",
will create default Username: notroot Password: notroot.


and

docker stop [container_ID]

docker start [container_ID]

Have fun!


