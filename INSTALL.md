#Perseus CITE Collections
##Prerequisites
This guide assumes that you have the following things set up on your machine:
* Ruby on Rails
* MySQL
* Access to [catalog_data](https://github.com/PerseusDL/catalog_data) and [catalog_pending](https://github.com/PerseusDL/catalog_pending) (You will want to remember to git pull the most recent versions)

##Installation
After completing the basic setup for the Rails project, (cloning the repo, bundle installing locally) you will need to do the following:
* create two yml files based off of the given sample files in /config, database.yml and config.yml
  * database.yml controls your interactions with MySQL
  * config.yml is where you provide a username and password for editing the table rows via the web interface
* `rake db:migrate`
* run MySQL commands located in data/load\_tables.sql to populate the db
* Some of the MADS paths are incorrect based on the current directory structure of catalog\_data, so run `rake mads_path_change` to update these

##Populating the database and creating Atom feeds
To import from catalog\_pending, `rake catalog_pending_import`, import will create new files in catalog\_data and eventually in catalog\_pending/errors if there are errors. Also eventually, it will delete files from catalog\_pending that it has created a corresponding file to in catalog\_data, then will run a git commit and git push to update both directories.

To build an atom feed, `rake build_atom_feed`, this will add ‘FRBR.feeds.all.(date)’ to the home directory of your machine.

Any errors that occur in either process will be documented in error logs located in catalog\_pending/errors and at the top level of the Atom feed directory.

##Viewing the CITE Tables
What follows is for a simple local installation, if you want to host this on a server, more work will be needed.

The CITE tables that you just uploaded and updated can now be viewed and searched in a browser.
* Start the rails server by running `rails server` in the directory
* In a browser navigate to http://localhost:3000
On the main page you will see four links and four searches, each corresponds to a CITE table: Author, Textgroup, Work, or Version. The links will take you to a full listing of everything in that table. Searching is done by column, selected with the drop-down lists to the left of the search boxes. Search results are shortened versions of the rows, to see the full data for a result, click on the 'Show' link.

You can also use the browser interface to edit rows in the CITE tables by selecting the 'Edit' link that appears to the far right of any row on the List or Search Result pages, or at the bottom of a Show page. Attempting to edit a row will result in a username and password prompt, these are the values you provided in config.yml.

##Resetting Everything
Since the import method creates and (will eventually) delete files, if something has gone wrong and it is necessary to reset all directories and databases involved, the sequence of steps to reset is the following:
* For catalog\_data and catalog\_pending
  * `git reset --hard HEAD`
  * `git clean -f -d`
* `rake add_orig_lang`
* reload db
  * `rake db:migrate:reset`
  * run the MySQL commands in the load\_tables file in /data/load_tables.sql

##Deploying in Apache with Phusion Passenger

	gem install passenger
	passenger-install-apache2-module

This server could be running on a system with other servers using a different version of ruby, so you might be using 

If you're using **rbenv** instead of **rvm** you might get an error message like this one...

	passenger-install-apache2-module: command not found

Here's what you do to fix it...

	rbenv version
		2.1.2 (set by /Users/username/.rbenv/version)
	cd /Users/username/.rbenv/versions/2.1.2/bin/
	./passenger-install-apache2-module

If **passenger-install-apache2-module** opens follow the prompts.

At the end of the install, you'll be given a **passenger_module** configuration snippet.

	LoadModule passenger_module /Users/username/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/gems/passenger-4.0.50/buildout/apache2/mod_passenger.so
	<IfModule mod_passenger.c>
	  PassengerRoot /Users/username/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/gems/passenger-4.0.50
	  PassengerDefaultRuby /Users/username/.rbenv/versions/2.1.2/bin/ruby
	</IfModule>

Add it to your Apache configuration file, most likely in **/etc/apache2/httpd.conf**.

Create a Virtual Host configuration.  If you're using a non-standard port number make sure you add a Listen config.
Replace **/var/www/cite_collections_rails** with your path to cite_collection_rails

	Listen 7890
	<VirtualHost *:7890>
		PassengerEnabled On
		DocumentRoot /var/www/cite_collections_rails/public
		RailsBaseURI /var/www/cite_collections_rails
		RailsEnv production
	   <Directory /var/www/cite_collections_rails/public>
		    Allow from all
		    Options -MultiViews
		</Directory>
	</VirtualHost>

If you get an error message like this...

	/Users/username/cite_collections_rails/config/config.yml could not be found

Try this...

	 ln -s /var/www/cite_collections_rails /Users/username/cite_collections
