# Migration of a Cyclescape installation to another machine

## 1. Essential DNS settings

Firstly, before starting, make sure that the TTL of the domain at the registrar is low, e.g. 300 seconds (5 minutes). This ensures that the DNS of the site will move quickly, rather than have people variously accessing two servers.

Do not switch over yet. See section 5 below which will cover that.

## 2. Set up the main Cyclescape software

To do this, use the cyclescape-chef cookbooks at:
https://github.com/cyclestreets/cyclescape-chef

Do not use the real mail credentials, as mail should only be processed by the single live installation.

## 3. Do a test migration

Use the script in this repository to copy across, and install, the last database backup dump and assets backup dump.

Edit the settings at the top. One of these settings results in a note of the original IP address of the current server being taken.

This script is repeatable, i.e. it can be re-run, and it will fetch the backup dumps, clean out the database and files and import them again.

To test the site is working, add to your /etc/hosts file a line such as

    new.server.ip.address www.cyclescape.org
    new.server.ip.address camcycle.cyclescape.org

and then load http://www.cyclescape.org/ in your browser.

If all is fine, you can now begin the main migration, as follows.

## 4. Stop the live site and run a backup on the source machine

Although an hourly backup should exist, data in the minutes since then won't be in it. ( https://github.com/cyclestreets/cyclescape-chef/blob/master/cookbooks/cyclescape-backups/recipes/default.rb#L33 defines the cron task that runs every hour.)

On the *LIVE* site, disable the cyclescape user's crontab which runs the mail ingester every 5 minutes:

    sudo -u cyclescape bash
    export EDITOR=<yourfavouriteeditor>
    crontab -e
    # Then comment out the 5-minutely cron job

Also disable the auto-updating script /root/monitor-update.sh in root's crontab by commenting-out the line with /root/monitor-update.sh in:

    sudo crontab -e

(Currently that is not part of the chef management - see ticket at ??? )

Then stop the (live) site and create a new backup (running as cyclescape) using:

    sudo service apache2 stop
    sudo service cyclescape stop
    sudo -u cyclescape bash /websites/cyclescape/backup/run-backups.sh

From this point on, the new server can be safely set running.

## 5. Re-run the migration script

Now switch to terminal where you are logged onto the *NEW* server.

Re-run the migration script, which will bring the new server's installation bang up to date.

## 6. Install the correct mail credentials

Now that the original server is no longer processing mail, and we have the latest data, the correct mail credentials should be put in.

As explained at https://github.com/cyclestreets/cyclescape-chef , the mailbox.json file needs to be edited. So run:

    sudo nano /etc/chef/databags/secrets/mailbox.json
    cd /opt/
    sudo chef-solo -c cyclescape-chef/solo.rb -j cyclescape-chef/node.json

Chef will use the values in that file to create the /var/www/cyclescape/shared/config/mailboxes.yml file.

Again, you can check the site is running in your browser on the machine with the /etc/hosts change. Any recent postings to the site will be visible.

## 7. Change the IP address of the site

Now that the new server is all correctly set up and running fine, log in to the registrar and switch the IP of the main domain to the new server.

Also, change any variants such as @ for .com/.net.

Remove the /etc/hosts entries on your local machine.

## 8. Install the auto-updating mechanism

As noted above, currently the updating script at /root/monitor-update.sh and its subscript /root/update-everything.sh is not part of chef. Above we disabled this on the original server.

Add this to the new server by copying in the script then adding to crontab -e :

    7 * * * * /bin/bash /root/monitor-update.sh

## 9. All done

The site will be running fine.

Useful tests to do are:

* Check that you can log in OK on both the main site and a subdomain
* Check that you can post to the site via the web interface
* Check that the posting comes through by e-mail (assuming you have mail subscription enabled)
* Send a reply by e-mail and check it appears on the web interface within 5 minutes


