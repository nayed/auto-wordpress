#!/bin/bash

# Check sudo
WHOAMI=$(whoami)
if [ "$WHOAMI" != "root" ] ; then
echo "You must be root to execute this script. Exiting now..." 
exit
fi

echo "Updating your distro"
apt-get update # > /dev/null


#
# Apache
#
echo "Installing Apache"
apt-get install -y apache2 libapache2-mod-php5 # > /dev/null

#
# PHP
#
echo "Installing PHP and libraries"
apt-get install -y language-pack-fr
locale-gen fr_FR.UTF-8

apt-get install -y curl
service apache2 restart

apt-get install -y php5 php5-cli php5-dev php-pear php5-mcrypt php5-curl php5-intl php5-gd mcrypt intl # > /dev/null


#
# MySQL
#
echo "Generating database root password"
rootpass=$(LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | head -c 12)
echo "Database root password is $rootpass"

echo "Installing MySQL"
debconf-set-selections <<< 'mysql-server mysql-server/root_password password $rootpass'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password $rootpass'
apt-get -q -y install mysql-server mysql-client php5-mysql # > /dev/null

# Create wordpress database and user
echo "Creating database and user for your wordpress"
dbname=$(LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | head -c 8)_wp
dbpass=$(LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | head -c 12)
mysql -uroot -p'$rootpass' -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO $dbname@localhost IDENTIFIED BY '$dbpass'"
echo "Database $dbname created for user $dbname with password $dbpass"

#
# Apache VHost
#
mkdir -p /var/www/myawesomesite.com/public
cd ~
echo '<VirtualHost *:80>
        DocumentRoot /var/www/myawesomesite.com/public
        ErrorLog  /var/www/myawesomesite.com/projects-error.log
        CustomLog /var/www/myawesomesite.com/projects-access.log combined
</VirtualHost>

<Directory "/var/www/myawesomesite.com">
        Options Indexes Followsymlinks
        AllowOverride All
        Require all granted
</Directory>' > myawesomesite.com.conf

mv myawesomesite.com.conf /etc/apache2/sites-available
a2enmod rewrite

#
# Reload apache
#
a2ensite myawesomesite.com
a2dissite 000-default
service apache2 restart

#
#  Cleanup
#
apt-get autoremove -y

usermod -a -G www-data vagrant

#
# Install Wordpress
#
cd /var/www/myawesomesite.com/public

echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

echo "Now Wordpress"
wp core download --allow-root

echo "WP user: "
read -e wpuser

echo "User email: "
read -e useremail

echo "User password: "
read -e password

echo "Site Name: "
read -e sitename

echo "Begin install"

wp core config --dbname=$dbname --dbuser=$dbname --dbpass=$dbpass --allow-root
wp core install --url="http://localhost" --title="$sitename" --admin_user="$wpuser" --admin_password="$password" --admin_email="$useremail" --allow-root

#
# Summing up everything
#
#
rm readme.html
wp theme install https://downloads.wordpress.org/theme/cista.1.0.zip --activate --allow-root
wp theme delete twentyfifteen --allow-root
wp theme delete twentyfourteen --allow-root
wp theme delete twentysixteen --allow-root

wp plugin delete akismet --allow-root
wp plugin delete hello --allow-root

wp plugin install duplicator --allow-root
wp plugin install wordfence --allow-root


echo -e "----------------------------------------"
echo -e "Your WP is now installed\n"
echo -e "----------------------------------------"
echo -e "Database credentials"
echo -e "----------------------------------------"
echo -e "root password : $rootpass"
echo -e "wordpress database name : $dbname"
echo -e "wordpress database password : $dbpass"
echo -e "Wordpress credentials"
echo -e "----------------------------------------"
echo -e "WP user : $wpuser"
echo -e "WP password : $password"
echo -e "WP email : $useremail"
echo -e "----------------------------------------"
echo -e "Now go to: http://192.168.33.10"
echo -e "Happy Wordpressing!"
echo -e "----------------------------------------"
