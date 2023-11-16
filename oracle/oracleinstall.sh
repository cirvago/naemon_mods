#!/bin/bash

set -e
set -u

PLUGIN_URL="https://labs.consol.de/assets/downloads/nagios/check_oracle_health-3.3.2.1.tar.gz"
PLUGIN_VER=$(echo "$PLUGIN_URL" | sed 's/.*check_oracle_health-\(.*\).tar.gz/\1/')

cat <<- EOF
	#######################################
	#                                     #
	# This is the installer script        #
	# for installing Oracle monitoring    #
	# libraries.                          #
	#                                     #
	# Before you continue, be sure that   #
	# the oracle-basic, sqlplus and devel #
	# are in the same directory as this   #
	# installer script.                   #
	# Need:				      #
	#  yum -y install redhat-lsb-core     #
	#                                     #
	#######################################
EOF

# get os and version
if which lsb_release &>/dev/null; then
    distro=`lsb_release -si`
    version=`lsb_release -sr`

elif [ -r /etc/redhat-release ]; then
    if rpm -q centos-release || rpm -q centos-linux-release; then
        distro=CentOS
	
	elif rpm -q centos-stream-release; then
		distro=CentOSStream

    elif rpm -q sl-release; then
        distro=Scientific

    elif rpm -q fedora-release; then
        distro=Fedora

    elif rpm -q redhat-release || rpm -q redhat-release-server; then
        distro=RedHatEnterpriseServer

    fi >/dev/null
    version=`sed 's/.*release \([0-9.]\+\).*/\1/' /etc/redhat-release`
else
    usage_error "Could not determine OS. Please make sure lsb_release is installed."
fi

# get os type
if [ "$distro" = "CentOS" ] || [ "$distro" = "CentOSStream" ] || [ "$distro" = "Scientific" ] || [ "$distro" = "Rocky" ] || [ "$distro" = "RedHatEnterpriseServer" ] || [ "$distro" = "RedHatEnterprise" ] || [ "$distro" = "OracleServer" ]; then
    ostype="rpm"
else
    ostype="deb"
fi

if [ "$ostype" == "rpm" ]; then
	# repo installs
	yum -y install glibc\* perl-YAML
	dnf -y install libxcrypt-4.1.1-6.el8.i686 libnsl2-devel.x86_64 libaio-devel.x86_64 libnsl python3-nagiosplugin.noarch perl-Nagios-Plugin.noarch perl-App-cpanminus

	# local installs
	yum -y --nogpgcheck localinstall  \
	oracle-instantclient*basic*.rpm   \
	oracle-instantclient*sqlplus*.rpm \
	oracle-instantclient*devel*.rpm
else
	# "$ostype" == "deb"
	# repo installs
	apt-get install -y libc6 libyaml-perl alien

	echo 'Converting RPMs to DEBs for installation. This may take several minutes...'
	echo -ne '(0/3)\r'
	# local installs
	alien -i oracle-instantclient*basic*.rpm >/dev/null
	echo -ne '(1/3)\r'
	alien -i oracle-instantclient*sqlplus*.rpm >/dev/null
	echo -ne '(2/3)\r'
	alien -i oracle-instantclient*devel*.rpm >/dev/null
	echo -ne '(3/3) '
	echo 'Finished installing!'
fi

### SETTING ENVIRONMENT VARIABLES

if arch | grep 64 >/dev/null; then
	client="client64"
else
	client="client"
fi

# Starting in version 18, oracle installs instantclient to /usr/lib/oracle/MAJOR.MINOR/client
# instead of /usr/lib/oracle/MAJOR/client

major_version=$(echo oracle-instantclient*basic*.rpm | sed 's/.*instantclient\([0-9.]*\)-basic-\([0-9.]*\-\).*/\2/' | cut -d . -f -1)
major_minor_version=$(echo oracle-instantclient*basic*.rpm | sed 's/.*instantclient\([0-9.]*\)-basic-\([0-9.]*\-\).*/\2/' | cut -d . -f -1,2)

version=$major_version
if (($major_version >= 18)); then
	version=$major_minor_version
fi

export ORACLE_HOME="/usr/lib/oracle/$version/$client"
export LD_LIBRARY_PATH="$ORACLE_HOME/lib"

### BEGIN CPAN INSTALL

echo "CPAN may ask you questions. Choose 'No' if it asks if you want to"
echo "do a manual install, unless you have special internet settings."

cpan -i DBI
cpan -i Test::NoWarnings
cpan -i strict
cpan -i warnings
cpanm -i CGI
cpanm -i DBI
cpanm -i Data::Dumper
cpanm -i strict
cpanm -i Log::Log4perl
cpanm -i Text::Levenshtein::XS
cpanm -i Text::Levenshtein::Damerau::XS
cpanm -i Text::Levenshtein
cpanm -i Text::Levenshtein::Damerau::PP
cpanm -i Bundle::CPAN

if [ "$ostype" == "rpm" ]; then
	# Check distro version
	ver=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
	ver=${ver:0:1}

	if [ "$ver" = "7" ] || [ "$ver" = "7Server" ]; then
	    if [ $version = 12.1 ]; then
	            cp -p /usr/share/oracle/$version/$client/demo/demo.mk /usr/share/oracle/$version/$client/demo.mk
	    fi
	fi
	
	if [ "$ver" = "8" ] || [ "$ver" = "9" ]; then
	    yum -y install libnsl
	fi
fi

# Normally, we would install the Oracle database driver with 
# cpan -i DBD::Oracle
# However, with newer versions of the Oracle client, this now requires immediate 
# access to an Oracle database, otherwise the tests fail ("Unable to connect to 
# Oracle") and the package does not install. Instead, we use the line below to
# install without running tests.

perl -MCPAN -e 'CPAN::Shell->rematein("notest", "install", "DBD::Oracle")'

# BEGIN SOURCE INSTALL :(

echo "Beginning source install..."
wget "$PLUGIN_URL"
tar xvf check_oracle_health-$PLUGIN_VER.tar.gz

(
	cd check_oracle_health-$PLUGIN_VER
	./configure --prefix=/usr/lib64/naemon/plugins/oracle/ --with-mymodules-dir=/usr/lib64/naemon/plugins/oracle/ --with-mymodules-dyn-dir=/usr/lib64/naemon/plugins/oracle/ --with-nagios-user=naemon --with-nagios-group=naemon --with-perl=/usr/bin/perl --with-statefiles-dir=/tmp
	make && make install
	mv /usr/lib64/naemon/plugins/oracle/libexec/check_oracle_health /usr/lib64/naemon/plugins/oracle/.
)

if [ "$ostype" == "deb" ]; then
    # Ludmil and I ran into some issues that we were able to clean up after install.
	# This might not be the "right" place for some of this but it should work 
	# -swolf 2023-01-25
    ln -s /usr/lib/oracle/$version/$client/lib/libclntshcore.so.* /usr/lib/oracle/$version/$client/lib/libclntshcore.so
	cpan -i Test::NoWarnings
	cpan -i DBD::Oracle
fi

# DO MKDIR
mkdir /var/tmp/check_oracle_health
chown -R nagios /var/tmp/check_oracle_health

echo "Add profile"
echo "export ORACLE_HOME=/usr/lib/oracle/$version/$client"
echo "export LD_LIBRARY_PATH=/usr/lib/oracle/$version/$client/lib"
echo "export ORACLE_BASE=/usr/lib/oracle/$version"
echo "export LD_RUN_PATH=/usr/local/lib"
echo "export TNS_ADMIN=$ORACLE_HOME/network/admin"
echo "export PATH=$PATH:/usr/lib/oracle/$version/$client/bin"
