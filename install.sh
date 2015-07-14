#!/bin/sh
# Write by EK. Which from Amoy FJ CN.
if
[ `grep "^$(whoami):" /etc/passwd | cut -d: -f4` -ne 0 ]
then
echo "You must Run this script as root!!!"
exit 1
fi
if
[ -z "$GITHUB_OAUTH" ]
then
cat <<EOF
need GITHUB_OAUTH!
Please visit https://github.com/settings/tokens/new?scopes=repo&description=Composer+on+ubuntu+$(date +%Y-%m-%d+%H%M)
Regen the toekn
and last export the GITHUB_OAUTH like:
export GITHUB_OAUTH="b6afad3751e8057ffee02a93eb718db5"
EOF
exit 1
fi

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
}
username=$(ls /home/ | sed -n 1p)
if
[ -n "$username" ]
then
USER_NAME="$username"
else
initialize
fi

useradd $USER_NAME -m -G sudo,www-data,adm -s /bin/bash
su -l $USER_NAME <<'CMD'
touch ~/.flarumrc
CMD
generate_ssl()
{
##### Generate random certificate
echo ">>> Installing *.flarum.dev self-signed SSL"

SSL_DIR="/etc/ssl/flarum.dev"
DOMAIN="*.flarum.dev"
PASSPHRASE="flarum"

SUBJ="
C=US
ST=Connecticut
O=flarum
localityName=Coruscant
commonName=$DOMAIN
organizationalUnitName=
emailAddress=
"

mkdir -p "$SSL_DIR"

openssl genrsa -out "$SSL_DIR/flarum.dev.key" 1024
openssl req -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key "$SSL_DIR/flarum.dev.key" -out "$SSL_DIR/flarum.dev.csr" -passin pass:$PASSPHRASE
openssl x509 -req -days 365 -in "$SSL_DIR/flarum.dev.csr" -signkey "$SSL_DIR/flarum.dev.key" -out "$SSL_DIR/flarum.dev.crt"
##### Generate random certificate
}

base_setting()
{
##### System Base setting
rm -f /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
locale-gen C.UTF-8

export LANG=C.UTF-8
grep -q "export LANG=C.UTF-8" ~/.bashrc || echo "export LANG=C.UTF-8" >> /root/.bashrc

apt-get update
apt-get install -y curl wget unzip git-core ack-grep software-properties-common python-software-properties
##### System Base setting
}

php_ins()
{
##### PHP Installtion
apt-get purge -y php*
apt-get autoremove -y
apt-get autoclean -y
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C
# php5.5 do
# add-apt-repository -y ppa:ondrej/php5
# php5.6 do
add-apt-repository -y ppa:ondrej/php5-5.6
apt-key update
apt-get update

apt-get install -y php5-cli php5-fpm php5-mysql php5-pgsql php5-sqlite php5-curl php5-gd php5-gmp php5-mcrypt php5-memcached php5-imagick php5-intl php5-xdebug

sed -i "s/listen =.*/listen = 127.0.0.1:9000/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen.allowed_clients/listen.allowed_clients/" /etc/php5/fpm/pool.d/www.conf

# Set user for PHP runer
# to avoid permission errors from apps writing to files
sed -i "s/user = www-data/user = $USER_NAME/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = $USER_NAME/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/listen\.owner.*/listen.owner = $USER_NAME/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = $USER_NAME/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/listen\.mode.*/listen.mode = 0666/" /etc/php5/fpm/pool.d/www.conf

# xdebug Config
cat > $(find /etc/php5 -name xdebug.ini) << EOF
zend_extension=$(find /usr/lib/php5 -name xdebug.so)
xdebug.remote_enable = 1
xdebug.remote_connect_back = 1
xdebug.remote_port = 9000
xdebug.scream=0
xdebug.cli_color=1
xdebug.show_local_vars=1

; var_dump display
xdebug.var_display_max_depth = 5
xdebug.var_display_max_children = 256
xdebug.var_display_max_data = 1024
EOF

# PHP Error Reporting Config
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini

# PHP Date Timezone
sed -i "s/;date.timezone =.*/date.timezone = Asia\/Shanghai/" /etc/php5/fpm/php.ini
sed -i "s/;date.timezone =.*/date.timezone = Asia\/Shanghai/" /etc/php5/cli/php.ini

# service php5-fpm restart
service php5-fpm stop
php_start
##### PHP Installtion
}

nginx_ins()
{
##### Nginx Installtion
echo ">>> Installing Nginx"
server_ip="0.0.0.0"
public_folder=/www
hostname="flarum.dev"

# Add repo for latest stable nginx
add-apt-repository -y ppa:nginx/stable

# Update Again
apt-get update

# Install Nginx
# -y implies -y --force-yes
apt-get install -y nginx

# Turn off sendfile to be more compatible with Windows, which can't use NFS
sed -i 's/sendfile on;/sendfile off;/' /etc/nginx/nginx.conf

# Set run-as user for PHP5-FPM processes to user/group "$USER_NAME"
# to avoid permission errors from apps writing to files
sed -i "s/user www-data;/user $USER_NAME;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

# Add $USER_NAME user to www-data group
usermod -a -G www-data $USER_NAME

cat <<'EOF' > /etc/nginx/sites-available/default
    server {
        listen 80;

        root /www;
        index index.html index.htm index.php app.php app_dev.php;

        # Make site accessible from ...
        server_name flarum.dev;

        access_log /var/log/nginx/default-access.log;
        error_log  /var/log/nginx/default-error.log error;

        charset utf-8;

        location / {
            try_files $uri $uri/ /app.php?$query_string /index.php?$query_string;
        }

        location = /favicon.ico { log_not_found off; access_log off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        error_page 404 /index.php;

        # pass the PHP scripts to php5-fpm
        # Note: .php$ is susceptible to file upload attacks
        # Consider using: "location ~ ^/(index|app|app_dev|config).php(/|$) {"
        location ~ .php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+.php)(/.+)$;
            # With php5-fpm:
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param LARA_ENV local; # Environment variable for Laravel
            fastcgi_param HTTPS off;
        }

        # Deny .htaccess file access
        location ~ /\.ht {
            deny all;
        }
    }

    server {
        listen 443;

        ssl on;
        ssl_certificate     /etc/ssl/flarum.dev/flarum.dev.crt;
        ssl_certificate_key /etc/ssl/flarum.dev/flarum.dev.key;

        root /www;
        index index.html index.htm index.php app.php app_dev.php;

        # Make site accessible from ...
        server_name test.com;

        access_log /var/log/nginx/default-access.log;
        error_log  /var/log/nginx/default-error.log error;

        charset utf-8;

        location / {
            try_files $uri $uri/ /app.php?$query_string /index.php?$query_string;
        }

        location = /favicon.ico { log_not_found off; access_log off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        error_page 404 /index.php;

        # pass the PHP scripts to php5-fpm
        # Note: .php$ is susceptible to file upload attacks
        # Consider using: "location ~ ^/(index|app|app_dev|config).php(/|$) {"
        location ~ .php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+.php)(/.+)$;
            # With php5-fpm:
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param LARA_ENV local; # Environment variable for Laravel
            fastcgi_param HTTPS on;
        }

        # Deny .htaccess file access
        location ~ /\.ht {
            deny all;
        }
    }
EOF

# service nginx restart
service nginx stop
nginx_start
##### Nginx Installtion
}

mysql_ins()
{
# MySQL Installtion
echo ">>> Installing MySQL Server"

mysql_root_password=root
mysql_version=5.5
mysql_enable_remote="true"

mysql_package=mysql-server

if [ "$mysql_version" = "5.6" ]; then
    # Add repo for MySQL 5.6
	add-apt-repository -y ppa:ondrej/mysql-5.6

	# Update Again
	apt-get update

	# Change package
	mysql_package=mysql-server-5.6
fi

# Install MySQL without password prompt
apt-get purge -y mysql*
apt-get autoremove -y
apt-get autoclean -y

# Set username and password to 'root'
echo "mysql-server mysql-server/root_password password $mysql_root_password" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_password" | debconf-set-selections


# Install MySQL Server
apt-get install -y $mysql_package

# Make MySQL connectable from outside world without SSH tunnel
if [ "$mysql_enable_remote" = "true" ]; then
    # enable remote access
    # setting the mysql bind-address to allow connections from everywhere
    sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

    # adding grant privileges to mysql root user from everywhere
    # thx to http://stackoverflow.com/questions/7528967/how-to-grant-mysql-privileges-in-a-bash-script for this
    MYSQL=`which mysql`

    Q1="GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$1' WITH GRANT OPTION;"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}"

    $MYSQL -uroot -p$1 -e "$SQL"

    # service mysql restart
    service mysql stop
	mysql_start
fi
##### MySQL Installtion
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
memcached_ins()
{
##### MEMcached Installtion
apt-get install -y memcached
##### MEMcached Installtion
}

beanstalkd_ins()
{
##### Beanstalkd Installtion
apt-get install -y beanstalkd

# Set to start on system start
sed -i "s/#START=yes/START=yes/" /etc/default/beanstalkd

# Start Beanstalkd
service beanstalkd start
##### Beanstalkd Installtion
}

nodejs_ins()
{
su -l $USER_NAME <<'CMD'
. ~/.flarumrc
##### Nodejs Installtion

    echo ">>> Installing Node Version Manager"

    # Install NVM
cd ~
rm -rf .nvm
git clone https://github.com/creationix/nvm.git .nvm

PROFILE="~/.flarumrc"

grep -q "nvm.sh" ~/.flarumrc
if [ $? -ne 0 ]; then
cat <<'EOF' >> ~/.flarumrc
# This loads NVM
[ -x ~/.nvm/nvm.sh ] && . ~/.nvm/nvm.sh
# Add new NPM global packages location to PATH
export PATH=$PATH:~/npm/bin
# Add the new NPM root to NODE_PATH
export NODE_PATH=~/npm/lib/node_modules
EOF
fi
# SOURCE_STR="\n# This loads NVM\n[[ -s ~/.nvm/nvm.sh ]] && . ~/.nvm/nvm.sh"
# grep -q "nvm.sh" ~/.flarumrc ||printf "$SOURCE_STR" >> "$PROFILE"

    # Re-source user profiles
	echo $PATH
	. ~/.flarumrc
	echo $PATH
    echo ">>> Installing Node.js version $NODEJS_VERSION"
    echo "    This will also be set as the default node version"
# v0.12.7 2015-07-14
    # If set to latest, get the current node version from the home page
	NODEJS_VERSION=`curl -L 'nodejs.org' | grep 'Current Version' | awk '{ print $4 }' | awk -F\< '{ print $1 }'`
echo "Nodejs default version $NODEJS_VERSION"
# Install Node
    nvm install $NODEJS_VERSION

# Set a default node version and start using it
    nvm alias default $NODEJS_VERSION

    nvm use default

echo ">>> Starting to config Node.js"

# Change where npm global packages are located
    npm config set prefix ~/npm

CMD
##### Nodejs Installtion
}

nodejs_pkgs_ins()
{
##### Nodejs Packages Installtion
# Install (optional) Global Node Packages
su -l $USER_NAME <<'CMD'
echo $PATH
. ~/.flarumrc
echo $PATH
    echo ">>> Start installing Global Node Packages"
    npm install --verbose -g unshift bower gulp
CMD
##### Nodejs Packages Installtion
}

composer_ins()
{
##### Composer Installtion

su $USER_NAME <<'CMD'
cd ~
. ~/.flarumrc
[ -d ~/bin ] || mkdir ~/bin
grep -qw 'export PATH=$PATH:~/bin' ~/.flarumrc
if [ $? -ne 0 ];then
echo 'export PATH=$PATH:~/bin' >> ~/.flarumrc
. ~/.flarumrc
fi

# Contains all arguments that are passed
if
[ -z "$GITHUB_OAUTH" ]
then
echo "need GITHUB_OAUTH! visit https://github.com/settings/tokens/new?scopes=repo&description=Composer+on+ubuntu+$(date +%Y-%m-%d+%H%M)"
exit 1
fi
COMPOSER_PACKAGES="franzl/studio:dev-master"

# True, if composer is not installed
which composer
if [ $? -ne 0 ]; then
    echo ">>> Installing Composer"
        # Install Composer
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar ~/bin/composer

else
    echo ">>> Updating Composer"
        composer self-update
fi

	composer config -g github-oauth.github.com $GITHUB_OAUTH 

# Install Global Composer Packages if any are given
if [[ ! -z $COMPOSER_PACKAGES ]]; then
    echo ">>> Installing Global Composer Packages:"
    echo "    " $COMPOSER_PACKAGES
        # composer global require franzl/studio:dev-master
        composer -vvv global require $COMPOSER_PACKAGES
    # Add Composer's Global Bin to ~/.bashrc path
	grep -q 'COMPOSER_HOME=' ~/.flarumrc || (printf "\n\nCOMPOSER_HOME=\"~/.composer\"" >> ~/.flarumrc && printf "\n# Add Composer Global Bin to PATH\n%s" 'export PATH=$PATH:$COMPOSER_HOME/vendor/bin' >> ~/.flarumrc)
fi
CMD
##### Composer Installtion
}

flarum_env()
{
apt-get install -y phantomjs zsh exuberant-ctags

##### Flarum environment
service nginx stop
mv /www /www-$(date +%Y-%m-%d+%H%M)
git clone --recursive https://github.com/flarum/flarum.git /www
cd /www
git checkout 76533e4096eb252974eed4d4f438c2cd012e1ea3
chown -R $USER_NAME /www
su -l $USER_NAME <<'CMD'
. ~/.flarumrc
grep -q "flarumrc" ~/.bashrc
if [ $? -ne 0 ]; then
cat <<EOF >> ~/.bashrc

. ~/.flarumrc
EOF
fi

### Setup NPM globals and create necessary directories ###
mkdir -p ~/npm
cd ~
cp -r /www/system/vagrant/aliases ~/.flarum.aliases

### Create rc file ###
grep -q "flarum.aliases" ~/.flarumrc
if
[ $? -ne 0 ]
then
cat <<'EOF' >> ~/.flarumrc

. ~/.flarum.aliases
EOF
. ~/.flarumrc
fi
### Set up environment files and database ###
cp /www/system/.env.example /www/system/.env
mysql -u root -proot -e 'drop database flarum'
mysql -u root -proot -e 'create database flarum'

### Setup flarum/core and install dependencies ###
cd /www/system/core
composer -vvv install --prefer-dist
cd /www/system
composer -vvv install --prefer-dist
composer -vvv dump-autoload

cd /www/system/core/js
bower -V install
cd /www/system/core/js/forum
npm install --verbose
gulp
cd /www/system/core/js/admin
npm install --verbose
gulp

cd /www/system
php artisan -vvv vendor:publish
php artisan -vvv flarum:install
php artisan -vvv flarum:seed
CMD
##### Flarum environment
# service nginx start
nginx_start
}

base_setting
generate_ssl
mysql_ins
php_ins
nginx_ins
memcached_ins
beanstalkd_ins
nodejs_ins
nodejs_pkgs_ins
composer_ins
flarum_env
