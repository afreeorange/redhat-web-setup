#!/bin/bash

# Setup script for RHEL-based distros 
# Compatible with 5.x & 6.x releases
# Assumes a base/minimal install
# Nikhil Anand <nikhil@mantralay.org>

# --- Installation options ---

TIMEZONE_NEW="GMT"
ROOT_EMAIL='admin@'$(hostname)
SSH_PORT="9853"
SSH_KEY_PASSPHRASE=""
DISABLE_IPV6="yes"
ALLOW_SSH_ROOT_LOGIN="no"
VERBOSE_BOOT="no"
RUBYVERSION="ruby-1.9.3-p362"
FAVORITE_EDITOR="vim"

# --- Package options ---

INSTALL_BASIC_ONLY="no"

# Options used only if the above is set to "no"
INSTALL_APACHE="yes"
INSTALL_MONGODB="yes"
INSTALL_NGINX="yes"
INSTALL_PHP_MYSQL="yes"
INSTALL_POSTGRES="no"
INSTALL_PYTHON3="yes"


# === Lists ===

LIST_NTP_SERVERS="
time.nist.gov
ns.arc.nasa.gov
tick.usno.navy.mil
tock.usno.navy.mil
bernina.ethz.ch
ntp.cuhk.edu.hk
ntp.syd.dms.csiro.au
ntps1.pads.ufrj.br
"

LIST_REPO_KEYS="
RPM-GPG-KEY-EPEL*
IUS-COMMUNITY-GPG-KEY
RPM-GPG-KEY-rpmforge-dag
RPM-GPG-KEY-PGDG-91
RPM-GPG-KEY-nginx
"

LIST_REPO_FILES="
epel*.repo
ius*.repo
rpmforge*.repo
pgdg-91-redhat.repo
nginx.repo
"

LIST_SERVICES_ON="
crond
httpd
mongod
mysqld
nginx
ntpd
postgresql-9.1
"

LIST_SERVICES_OFF="
anacron
apmd
atd
autofs
avahi-daemon
bluetooth
cups
firstboot
hidd
hplip
isdn
kdump
mcstrans
messagebus
netfs
nfslock
pcscd
portmap
rhnsd
rpcgssd
rpcidmapd
settroubleshoot
xfs
"

LIST_PACKAGES_BASIC="
aide
amtu
audit
bind-utils
cronie
cronie-anacron
crontabs
curl
cvs
db4
db4-utils
ImageMagick
iptraf
java-1.7.0-openjdk
lsof
lvm2
mailx
man
mlocate
mod_ssl
mtr
mutt
nc
nmap
ntp
openldap-clients
openssh-clients
perl
postfix
python-setuptools
rpcbind
rsync
sharutils
subversion
tree
unzip
vim-enhanced
yum-utils
zip
"

LIST_PACKAGES_EPEL="
bash-completion
byobu
git
htop
iotop
multitail
ncdu
ntop
p7zip
p7zip-plugins
pbzip2
puppet
rkhunter
sysstat
"

LIST_PACKAGES_REPOFORGE="
bcrypt
iftop
pv
rar
siege
unrar
"

LIST_PACKAGES_MYSQL="
mysql55-server
mysql55-devel
mysqlclient16
"

LIST_PACKAGES_PHP="
php54
php54-cli
php54-common
php54-devel
php54-gd
php54-imap
php54-ldap
php54-mbstring
php54-mcrypt
php54-mysql
php54-pear.noarch
php54-pecl-geoip
php54-pecl-imagick
php54-snmp
php54-soap
php54-suhosin
php54-tidy
php54-xml
php54-xmlrpc
"

LIST_PACKAGES_PYTHON31="
python31
python31-distribute
python31-tools
tkinter31
"

LIST_PACKAGES_PYTHON32="
python32
python32-libs
python32-tkinter
python32-tools
"

LIST_PACKAGES_POSTGRES="
postgresql91
postgresql91-contrib
postgresql91-docs
postgresql91-jdbc
postgresql91-libs
postgresql91-server
"

###### STOP EDITING! ######

DASHES1="=============================="
DASHES2="------------------------------"
DASHES3="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# Color!
function redheader()    { echo -e "\n$1\n$DASHES3\n" >> setup.log.debug; echo -e "\E[31m$1"; tput sgr0; }
function greenheader()  { echo -e "\n$1\n$DASHES1\n" >> setup.log; echo -e "\E[32m$1"; tput sgr0; }
function yellowheader() { echo -e "\n$1\n$DASHES2\n" >> setup.log; echo -e "\E[33m$1"; tput sgr0; }
function cyanheader()   { echo -e "\n$1\n$DASHES1\n" >> setup.log; echo -e "\E[36m$1"; tput sgr0; }
function blueheader()   { echo -e "\n$1\n$DASHES2\n" >> setup.log; echo -e "\E[34m$1"; tput sgr0; }

# Decent, random passwords
function generate_password() {
  echo $(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 20 | xargs) 
}

# Keep installs quiet
function yumq() {
  COMMAND=$1
  yum $COMMAND 2>> setup.log.debug 1>> setup.log 
}
function rpm_install() {
  RESOURCE=$1

  # Can't do rpm -ivh with RPMforge or PGDG; have to download first
  wget --quiet --tries=3 -P /tmp $RESOURCE
  rpm -ivh /tmp/$(basename $RESOURCE) 2>> setup.log.debug 1>> setup.log
}

# Start & stop services
function start_service() {
  SERVICE_NAME=$1
  service $SERVICE_NAME start 2>> setup.log.debug 1>> setup.log
  chkconfig $SERVICE_NAME on 2>> setup.log.debug 1>> setup.log
}
function stop_service() {
  SERVICE_NAME=$1
  service $SERVICE_NAME stop 2>> setup.log.debug 1>> setup.log
  chkconfig $SERVICE_NAME off 2>> setup.log.debug 1>> setup.log
}

# Compile and install Ruby (/tmp is noexec, so use home)
function install_ruby() {
  cd 
  wget -O - http://ftp.ruby-lang.org/pub/ruby/1.9/$RUBYVERSION.tar.gz | tar -xzvf -
  chown -R 0:0 $RUBYVERSION/
  cd $RUBYVERSION
  chmod +x ./configure
  ./configure
  make
  make install
	cd .. && rm -rf $RUBYVERSION
}

# === Pre-Flight ===

PASSWORD_MYSQL=$(generate_password)
PASSWORD_ROOT=$(generate_password)

if [ "$INSTALL_BASIC_ONLY" == "yes" ]; then
  INSTALL_APACHE="no"
  INSTALL_MONGODB="no"
  INSTALL_NGINX="no"
  INSTALL_PHP_MYSQL="no"
  INSTALL_POSTGRES="no"
  INSTALL_PYTHON3="yes"
fi

# --- Check for superuser ---
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  redheader "! You are not a superuser. Aborting."
  exit 1
fi

# --- Get release information ---
VERSION=$(grep -o -E '[0-9]+' /etc/redhat-release)
VERSION_MAJOR=$(echo $VERSION | awk '{print $1}')
VERSION_MINOR=$(echo $VERSION | awk '{print $2}')

# --- Get architecture ---
ARCH=$(uname -i)
[[ "$ARCH" == "i686" ]] && ARCH="i386"
greenheader "+ Detected a $ARCH, RHEL(ish) $VERSION_MAJOR.$VERSION_MINOR system"

# --- Get timezone ---
TIMEZONE_CURRENT=$(grep -o -E '\".*\"' /etc/sysconfig/clock)

# --- Disable SELinux ---
greenheader  "+ Disabling SELinux"
setenforce 0 2>> setup.log.debug 1>> setup.log
if [ $VERSION_MAJOR == 5 ]; then
  sed -ie 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
else
  sed -ie 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
fi

# --- Stop firewall ---
greenheader  "+ Stopping firewall service temporarily"
service iptables stop &> /dev/null

# --- Update system ---
greenheader  "+ Updating system"
yumq "-y update yum python rpm"
yumq "-y install wget curl"
yumq "clean all"
yumq "-y update"
yumq "clean all"


# === Install Additional Repositories ===

greenheader  "+ Installing additional repositories"
yellowheader " - EPEL"
if [ $VERSION_MAJOR == 5 ]; then
  rpm_install http://dl.iuscommunity.org/pub/ius/stable/Redhat/5/$ARCH/epel-release-5-4.noarch.rpm
else
  rpm_install http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/$ARCH/epel-release-6-5.noarch.rpm
fi

yellowheader " - RepoForge"
rpm_install http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el$VERSION_MAJOR.rf.$ARCH.rpm

yellowheader " - IUS Community"
rpm_install http://dl.iuscommunity.org/pub/ius/stable/Redhat/$VERSION_MAJOR/$ARCH/ius-release-1.0-10.ius.el$VERSION_MAJOR.noarch.rpm

yellowheader " - MongoDB Repo"
cat > /etc/yum.repos.d/10gen.repo <<MONGOREPO
[10gen]
name=10gen Repository
baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/\$basearch
gpgcheck=0
enabled=0
includepkgs=mongo*
MONGOREPO

yellowheader " - PostgreSQL"
rpm_install http://yum.postgresql.org/9.1/redhat/rhel-$VERSION_MAJOR-$ARCH/pgdg-redhat91-9.1-5.noarch.rpm

yellowheader " - Nginx Repo"
rpm_install http://nginx.org/packages/centos/$VERSION_MAJOR/noarch/RPMS/nginx-release-centos-$VERSION_MAJOR-0.el$VERSION_MAJOR.ngx.noarch.rpm


# === Configure Repositories ===

greenheader  "+ Configuring repositories"
yellowheader " - Importing keys"
for GPG_KEY in $LIST_REPO_KEYS; do rpm --quiet --import /etc/pki/rpm-gpg/$GPG_KEY; done

yellowheader " - Disabling repos"
for GPG_FILE in $LIST_REPO_FILES; do sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/$GPG_FILE; done


# === Install Packages ===

greenheader  "+ Installing packages"

# --- Remove older packages ---
yellowheader " - Cleaning older packages"
rpm -e --quiet --nodeps mysql-libs &> /dev/null
for php_rpm in $(rpm -qa | grep php); do rpm -e $php_rpm --nodeps; done
yumq "-y install mysqlclient16 mysql55-libs --enablerepo=ius" # Needed by postfix later

# --- Base Repositories ---
yellowheader " - Development tools and libraries"
yum -y groupinstall "Development Tools" 2>> setup.log.debug 1>> setup.log # Couldn't figure out escaping strings...
yumq "-y install vim-enhanced httpd readline readline-devel ncurses-devel gdbm-devel glibc-devel \
tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc \
sqlite-devel gcc-c++ libyaml libyaml-devel libffi libffi-devel \
libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel \
system-config-firewall-tui python-devel redis sudo wget \
crontabs logwatch logrotate sendmail-cf qtwebkit qtwebkit-devel \
perl-Time-HiRes"

yellowheader " - Basic packages"
yumq "-y install $LIST_PACKAGES_BASIC"

# --- External Repositories ---
yellowheader " - Additional packages from external repositories"
yumq "-y install $LIST_PACKAGES_EPEL --enablerepo=epel"
yumq "-y install $LIST_PACKAGES_REPOFORGE --enablerepo=rpmforge"

if [ "$INSTALL_BASIC_ONLY" == "no" ]; then

  if [ "$INSTALL_APACHE" == "yes" ]; then
    yellowheader "   Apache"
    yumq "-y install httpd"
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/httpd/conf/httpd.conf
    echo "Hello." >> /var/www/html/index.html
  fi

  if [ "$INSTALL_PHP_MYSQL" == "yes" ]; then
    yellowheader "   PHP & MySQL"
    yumq "-y install $LIST_PACKAGES_MYSQL --enablerepo=ius"
    yumq "-y install $LIST_PACKAGES_PHP --enablerepo=ius"
  fi

  if [ "$INSTALL_MONGODB" == "yes" ]; then
    yellowheader "   MongoDB"
    yumq "-y install mongo-10gen mongo-10gen-server --enablerepo=10gen"
  fi

  if [ "$INSTALL_POSTGRES" == "yes" ]; then
    yellowheader "   PostgreSQL 9 Repo"
    yumq "-y install $LIST_PACKAGES_POSTGRES --enablerepo=pgdg91"
  fi

  if [ "$INSTALL_NGINX" == "yes" ]; then
    yellowheader "   Nginx"
    yumq "-y install nginx --enablerepo=nginx"
    cp /etc/nginx/conf.d/default.conf{,.original}
    sed -i 's/listen.*80/listen 8888/' /etc/nginx/conf.d/default.conf
  fi

else
  yellowheader "   PHP"
  yumq "-y install php54 php54-cli --enablerepo=ius"

fi

if [ "$INSTALL_PYTHON3" == "yes" ]; then
  yellowheader "   Python 3"
  if [ $VERSION_MAJOR == 5 ]; then
    yumq "-y install $LIST_PACKAGES_PYTHON31 --enablerepo=ius" 
  else
    yumq "-y install $LIST_PACKAGES_PYTHON32 --enablerepo=ius" 
  fi

  if [ "$INSTALL_APACHE" == "yes" ]; then
    yumq "-y install python3*-mod_wsgi --enablerepo=ius"
  fi
fi

yellowheader "   Ruby"
install_ruby 2>> setup.log.debug 1>> setup.log 

yellowheader " - Miscellaneous"
wget --tries=2 --quiet -O /usr/local/bin/ack http://betterthangrep.com/ack-standalone && chmod 755 /usr/local/bin/ack


# === Security ===

greenheader  "+ Basic security"

yellowheader " - Securing /tmp"
rm -rf /tmp
mkdir /tmp
mount -t tmpfs -o rw,noexec,nosuid tmpfs /tmp
chmod 1777 /tmp
echo "tmpfs /tmp tmpfs rw,noexec,nosuid 0 0" >> /etc/fstab
rm -rf /var/tmp
ln -s /tmp /var/tmp

yellowheader " - Securing /dev/shm"
umount /dev/shm 
rm -rf /dev/shm
mkdir /dev/shm
mount -t tmpfs -o rw,noexec,nosuid tmpfs /dev/shm
chmod 1777 /dev/shm
echo "tmpfs /dev/shm tmpfs rw,noexec,nosuid 0 0" >> /etc/fstab

yellowheader " - Setting root alias"
sed -i 's/#root:\s*marc/root:\t\t'"${ROOT_EMAIL}"'/g' /etc/aliases

if [ "$SSH_PORT" != "22" ]; then
  yellowheader " - Changing SSH port"
  sed -i 's/#Port/Port/' /etc/ssh/sshd_config
  sed -i 's/Port.*/Port 9853/' /etc/ssh/sshd_config
fi

if [ "$ALLOW_SSH_ROOT_LOGIN" == "no" ]; then
  yellowheader " - Disabling root login"
  sed -i 's/#PermitRootLogin/PermitRootLogin/' /etc/ssh/sshd_config
  sed -i 's/PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
fi

yellowheader " - AIDE"
aide --init 2>> setup.log.debug 1>> setup.log
mv /var/lib/aide/{aide.db.new.gz,aide.db.gz}

yellowheader " - Rootkit Hunter"
echo -e "PKGMGR=RPM" >> /etc/rkunter.conf
rkhunter --propupd 2>> setup.log.debug 1>> setup.log

yellowheader " - Postfix as default MTA"
ln -s /usr/sbin/sendmail.postfix /etc/alternatives/mta --force

yellowheader " - Disabling ctrl+alt+del for shutdown"
if [ $VERSION_MAJOR == 5 ]; then
  sed -i 's/^ca::ctrlaltdel/#ca::ctrlaltdel/' /etc/inittab
else
  sed -i 's/^exec/# exec/' /etc/init/control-alt-delete.conf 
fi

if [ "$DISABLE_IPV6" == "yes" ]; then
  yellowheader " - Disabling IPV6"
  echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
  cat >> /etc/sysctl.conf <<IPV6

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
IPV6
fi

yellowheader " - Auditd, authconfig, etc"
echo "NOZEROCONF=yes" >> /etc/sysconfig/network
chkconfig auditd on
authconfig --passalgo=sha512 --update

# === Miscellaneous ===

greenheader  "+ Wrapping up"
yellowheader " - Setting timezone to $TIMEZONE_NEW (was $TIMEZONE_CURRENT)"
rm /etc/localtime
ln -s /usr/share/zoneinfo/$TIMEZONE_NEW /etc/localtime

yellowheader " - Create user homedirs if they don't exist"
echo "session    required     pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/system-auth

yellowheader " - Configuring NTP"
sed -i 's/^server/#server/' /etc/ntp.conf
for NTP_SERVER in $LIST_NTP_SERVERS; do echo "server "$NTP_SERVER >> /etc/ntp.conf; echo $NTP_SERVER >> /etc/ntp/step-tickers; done

yellowheader " - Dressing up root's crontab"
cat >> /var/spool/cron/root <<CRONTAB
# +---------------- minute (0 - 59)
# |  +------------- hour (0 - 23)
# |  |  +---------- day of month (1 - 31)
# |  |  |  +------- month (1 - 12)
# |  |  |  |  +---- day of week (0 - 7) (Sunday=0 or 7)
# |  |  |  |  |
# *  *  *  *  *
CRONTAB

yellowheader " - Starting required services"
for SERVICE in $LIST_SERVICES_ON; do start_service $SERVICE; done

yellowheader " - Stopping unnecessary services"
for SERVICE in $LIST_SERVICES_OFF; do stop_service $SERVICE; done

if [ "$VERBOSE_BOOT" == "yes" ]; then
  yellowheader " - Making bootup more verbose"
  sed -i 's/rhgb\|quiet//g' /boot/grub/grub.conf &> /dev/null
fi

yellowheader " - Generating SSH keys"
ssh-keygen -q -N "$SSH_KEY_PASSPHRASE" -t rsa -f ~/.ssh/id_rsa
ssh-keygen -q -N "$SSH_KEY_PASSPHRASE" -t dsa -f ~/.ssh/id_dsa

yellowheader " - Updating mlocate"
updatedb

yellowheader " - Miscellaneous"
rm -f /tmp/*.rpm
chkconfig iptables on
echo "export EDITOR=$FAVORITE_EDITOR" >> ~/.bash_profile

# I got lazy here...
LISTENING_PORTS=$(netstat -tln | awk '{print $4}' | grep '^0.*' | cut -d: -f2 | sort | tr '\n' ' ')

blueheader   "+ All done!"
cyanheader   "+ Please do the following NOW:
  - Configure your firewall
    ~ Make sure you allow the SSH port you've chosen (port $SSH_PORT)!
    ~ Your applications are listening on the following ports: 
      $LISTENING_PORTS
  - Set up MySQL if installed. Here's a password: $PASSWORD_MYSQL
  - Copy the AIDE files (/var/lib/aide) to a secure location
  - Change your root password. Suggestion: $PASSWORD_ROOT
+ REBOOT when you're done!\n"
