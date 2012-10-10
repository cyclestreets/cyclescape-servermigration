#!/bin/sh
# Script to migrate Cyclescape data to new machine


### SETTINGS ###

SOURCESITEIP=46.235.224.112
SITEOWNER=cyclekit.cyclekit


### MAIN PROGRAM ###

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

# Set the user to retrieve the backups from
echo "Retrieve the backups from ${SOURCESITEIP} as which user? :"
read SCRIPTUSERNAME

# Get the backups (will prompt for password)
echo "Retrieving the backups..."
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeDB.sql.gz
sudo -u $SCRIPTUSERNAME scp $SCRIPTUSERNAME@$SOURCESITEIP:/websites/cyclescape/backup/cyclescapeDB.sql.gz /tmp/
sudo -u $SCRIPTUSERNAME rm -f /tmp/toolkitShared.tar.bz2
sudo -u $SCRIPTUSERNAME scp $SCRIPTUSERNAME@$SOURCESITEIP:/websites/cyclescape/backup/toolkitShared.tar.bz2 /tmp/

# Unzip the backups
echo "Unzipping the backups..."
sudo -u $SCRIPTUSERNAME gunzip /tmp/cyclescapeDB.sql.gz
sudo -u $SCRIPTUSERNAME tar xfj /tmp/toolkitShared.tar.bz2 -C /tmp/

# Notes on connecting to Postgres - best to use main account as logging in won't complain about a missing database
#su - postgres psql
# \list shows all databases
# \c cyclekit_production to change database
# \dt shows tables in that database
# \q to exit

# Stop relevant services
# Note that the Toolkit services are defined at https://github.com/cyclestreets/toolkit/blob/master/Procfile
# There's a gem called foreman which takes this procfile, and generates a bunch of Upstart files from it.
echo "Stopping the Apache and Toolkit services..."
service apache2 stop
service toolkit stop

# Manually drop the db and recreate it
echo "Creating a clean Postgres database..."
sudo -u postgres dropdb cyclekit_production
sudo -u postgres createdb -O cyclekit cyclekit_production

# Import the data (quietly - see http://petereisentraut.blogspot.co.uk/2010/03/running-sql-scripts-with-psql.html )
echo "Importing the toolkit database dump..."
sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -X -q -a -v ON_ERROR_STOP=1 --pset pager=off -d cyclekit_production -f /tmp/cyclescapeDB.sql

# Add the user assets
echo "Adding the user assets..."
rm -rf /var/www/toolkit/shared/system/dragonfly/production/
cp -pr /tmp/shared/system/dragonfly /var/www/toolkit/shared/system/
chown -R $SITEOWNER /var/www/toolkit/shared/system/dragonfly

# Start relevant services
echo "Starting the Apache and Toolkit services..."
service toolkit start
service apache2 start

# Clean up temporary files
echo "Removing temporary files"
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeDB.sql
sudo -u $SCRIPTUSERNAME rm -f /tmp/toolkitShared.tar.bz2
sudo -u $SCRIPTUSERNAME rm -rf /tmp/shared/
