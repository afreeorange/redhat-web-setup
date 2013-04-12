Setup Script for RHEL-based Web Servers
=======================================

Introduction
------------

A quick setup script for Red Hat-based web servers I used frequently.
Compatible with 5.x and 6.x releases. Script assumes a base/minimal
vanilla install.

Please edit the first few lines of the script to configure some options.
If `INSTALL_BASIC_ONLY` is set to "yes", the script sets up:

* Quite a few useful tools, languages, libraries, and services
* Many external repositories, which are only enabled for certain packages

Setting `INSTALL_BASIC_ONLY` to "no" will install a LAMP stack, Nginx,
and MongoDB.

Output is appended to `setup.log`. Errors are sent to `setup.log.debug`

Defaults
--------

* Timezone is set to GMT; you'll want to change this
* IPV6 is disabled
* Default editor is vim
* Root email is sent to admin@(server hostname)
* For SSH:
    * Root login is disabled
    * Port is set to **9853** (RHEL = 18-8-5-12)
* NTP uses a few servers [off this page](http://infohost.nmt.edu/~armiller/timeserv.htm)
* Nginx default port is set to **8888**

External Repositories
---------------------

The script installs and uses many external repositories *selectively*.
For example, IUS is only ever used for PHP 5.4+ and MySQL 5.5+. They are
all disabled (i.e., `enabled=0` in corresponding `.repo` files) after
they're installed.

* [EPEL](http://fedoraproject.org/wiki/EPEL)
* [RepoForge](http://repoforge.org/)
* [IUS](http://iuscommunity.org/pages/About.html)
* [MongoDB](http://docs.mongodb.org/manual/tutorial/install-mongodb-on-redhat-centos-or-fedora-linux/)
* [Ngnix](http://nginx.org/en/download.html)
* [PGDG](http://wiki.postgresql.org/wiki/RPM_Installation)

Packages Installed
------------------

### Basic Packages

* Languages: Python 2.7 & 3.1 (RHEL5) or 3.3 (RHEL6), PHP 5.4, Ruby 1.9.3, Perl 5.10,
    Java 1.7 (OpenJDK)
* Monitoring utilities: htop, ntop, iotop, ncdu, sysstat, iftop,
    iptraf
* Source Control: Subversion, git, cvs
* Archival: zip, rar, pbzip2, 7-zip
* Security: rkhunter, AIDE, bcrypt, Suhosin for PHP
* Miscellaneous: ack, byobu, tree, siege, mlocate, pv, vim, yum-utils,
    multitail, bash-completion, puppet, bcrypt, and many more
* Development libraries and tools

### Additional packages

* Databases: MongoDB 2.2, MySQL 5.5, and PostgreSQL 9.1
* The Apache 2.2 and Nginx v1.2 web servers

SELinux
-------

Disabled for now. I'm sure it's awesome. [This project](https://github.com/nmoureyii/centos-setup) seems like a
good starting point.

License
-------

MIT. See `LICENSE`