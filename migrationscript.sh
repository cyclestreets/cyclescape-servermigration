#!/bin/sh
# Script to migrate Cyclescape data to new machine


### SETTINGS ###

SOURCESITEIP=93.93.135.180
SITEOWNER=cyclescape.cyclescape


### MAIN PROGRAM ###

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root; aborting." 1>&2
	exit 1
fi

# Ensure the cyclescape-chef recipes and mailbox file are present
if [ ! -d "/opt/cyclescape-chef" ]; then
	echo "The cyclescape-chef recipes are not present in /opt/cyclescape-chef"
	exit 1
fi
if [ ! -f "/etc/chef/databags/secrets/mailbox.json" ]; then
	echo "The file /etc/chef/databags/secrets/mailbox.json is not present"
	exit 1
fi

# Bring the chef recipes up-to-date
echo "Bringing the chef recipes up-to-date"
cd /opt/cyclescape-chef/
git pull

# Bring the main installation up-to-date
echo "Bringing the main installation up-to-date"
cd /opt/
sudo chef-solo -c cyclescape-chef/solo.rb -j cyclescape-chef/node.json

# Set the user to retrieve the backups from
echo "Retrieve the backups from ${SOURCESITEIP} as which user?:"
read SCRIPTUSERNAME

# Clean up any temporary files from any previous script invocation
echo "Removing temporary files from any previous script invocation"
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeDB.sql
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeShared.tar.bz2
sudo -u $SCRIPTUSERNAME rm -rf /tmp/shared/

# Get the backups (will prompt for password)
echo "Retrieving the backups..."
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeDB.sql.gz
sudo -u $SCRIPTUSERNAME scp $SCRIPTUSERNAME@$SOURCESITEIP:/websites/cyclescape/backup/cyclescapeDB.sql.gz /tmp/
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeShared.tar.bz2
sudo -u $SCRIPTUSERNAME scp $SCRIPTUSERNAME@$SOURCESITEIP:/websites/cyclescape/backup/cyclescapeShared.tar.bz2 /tmp/

# Unzip the backups
echo "Unzipping the backups..."
sudo -u $SCRIPTUSERNAME gunzip /tmp/cyclescapeDB.sql.gz
sudo -u $SCRIPTUSERNAME tar xfj /tmp/cyclescapeShared.tar.bz2 -C /tmp/

# Notes on connecting to Postgres - best to use main account as logging in won't complain about a missing database
#su - postgres psql
# \list shows all databases
# \c cyclescape_production to change database
# \dt shows tables in that database
# \q to exit

# Stop relevant services
# Note that the Cyclescape services are defined at https://github.com/cyclestreets/cyclescape/blob/master/Procfile
# There's a gem called foreman which takes this procfile, and generates a bunch of Upstart files from it.
echo "Stopping the Apache and Cyclescape services..."
service apache2 stop
service cyclescape stop

# Wait for a short while to enable any connections to the database to close
echo "Waiting a short while to enable any connections to the database to close..."
sleep 20

# Manually drop the db and recreate it
echo "Creating a clean Postgres database..."
sudo -u postgres dropdb cyclescape_production
sudo -u postgres createdb -O cyclescape cyclescape_production

# Import the data (quietly - see http://petereisentraut.blogspot.co.uk/2010/03/running-sql-scripts-with-psql.html )
echo "Importing the Cyclescape database dump..."
sudo -u postgres PGOPTIONS='--client-min-messages=warning' psql -X -q -a -v ON_ERROR_STOP=1 --pset pager=off -d cyclescape_production -f /tmp/cyclescapeDB.sql

# Archive any previous user assets folder for safety (though there should be a backup anyway)
if [ -d "/var/www/cyclescape/shared/system/dragonfly/production/" ]; then
	echo "Archiving previous user assets folder for safety..."
	timestamp=`date +%s`
	mv /var/www/cyclescape/shared/system/dragonfly/production "/var/www/cyclescape/shared/system/dragonfly/production.backup.${timestamp}"
fi

# Add the user assets
echo "Adding the user assets..."
cp -pr /tmp/shared/system/dragonfly /var/www/cyclescape/shared/system/
chown -R $SITEOWNER /var/www/cyclescape/shared/system/dragonfly

# Start relevant services
echo "Starting the Apache and Cyclescape services..."
service cyclescape start
service apache2 start

# Clean up temporary files
echo "Removing temporary files"
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeDB.sql
sudo -u $SCRIPTUSERNAME rm -f /tmp/cyclescapeShared.tar.bz2
sudo -u $SCRIPTUSERNAME rm -rf /tmp/shared/
