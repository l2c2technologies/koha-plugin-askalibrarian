# Introduction
The Koha OPAC is a functionality rich environment with plenty of scope for user interaction and use. However, one standard feature of most Web 2.0 applications - a feedback form that users can use to leave a message to the admins, was missing in Koha. The AskALibrarian koha plugin is meant to address that gap as an integrated 'koha-native' solution that uses Koha's plugin system to deliver the feedback form functionality to Koha.

### How does it work

The plugin adds a bootstrap modal feedback form as a menu option on the _navbar_ at the top of the Koha OPAC. On submission of the form by the user / visitor, the information is submitted via an AJAX call to a Perl script _(i.e. askalibrarian.pl)_ on the staff client side. The script invokes the required sub-routines from the plugin to do **two** things : (a) send the user an acknowledgement of the submitted input at the email address, it provided is reachable and (b) store the submitted data in the `koha_plugin_com_l2c2technologies_askalibrarian_feedback` table in the Koha database. A callback sends up an alert popup on the OPAC, informing if it has successfully captured the data.

### What is a Koha plugin
Koha’s Plugin System (available in Koha 3.12+) allows us to add additional tools and reports to [Koha](http://koha-community.org) that are specific to our library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the Perl files, template files, and any other files necessary to make the plugin work. 

# Downloading

From the [release page](https://github.com/l2c2technologies/koha-plugin-askalibrarian/releases) we can download the relevant *.kpz file

# Installing

Upload the KPZ ( Koha Plugin Zip ) package _(downloaded in the previous step)_ by going to `Administration -> Manage plugins -> Upload plugin`. 

### Preparations that are required before installation.
The plugin system needs to be turned on by a system administrator. To set up the Koha plugin system we must first make some changes to our Koha instance.

* Change `<enable_plugins>0<enable_plugins>` to `<enable_plugins>1</enable_plugins>` in your instance's koha-conf.xml file
* You will also need to **enable** your `UseKohaPlugins` system preference. 

AskALibrarian plugin generates email-based user notifications. So, we must also have email configured and working for our Koha. The `KohaAdminEmailAddress` system preference **must** be setup correctly. The plugin uses the email specified in it to send out the user notifications.

### Post installation configuration

**N.B.** Koha will install the KPZ file into `/var/lib/koha/<instance_name>` directory. For the example used in this README, our `<instance_name>` is _covas_. Your instance name will be different. So you **must** remember to change it to your Koha instance name when applying the next step. 

Since the feedback form needs to access the `askalibrarian.pl` from the OPAC and we do not want it to set off false XSS attack alarms, we have to add the following change to the Apache configuration at `/etc/koha/apache-shared-opac.conf`. 

````
ScriptAlias /askalibrarian.pl "/var/lib/koha/covas/plugins/Koha/Plugin/Com/L2C2Technologies/AskALibrarian/askalibrarian.pl"

Alias /plugin/ "/var/lib/koha/covas/plugins/"
# The stanza below is needed for Apache 2.4+
<Directory /var/lib/koha/covas/plugins/>
     Options Indexes FollowSymLinks
     AllowOverride None
     Require all granted
</Directory>
````

**IMPORTANT:** Remember to change **_all_** references from `covas` to that of your own instance name.

# Configuring the plugin

The AskALibrarian plugin allows you to capture an additional data point - `User type`. During installation, a blank `Local use` system preference is added - `UserDesignation`. If you want to use this optional field, you should configure it before proceeding further.

The `UserDesignation` sys pref accepts a set of values delimited by `|` (the pipe symbol). Below is an example of the set of values we used for a particular client:

````
 Student|Research Scholar|Faculty|Staff|Visitor|Others
````

Go to `Administration -> Manage plugins`, click on the 'Configure' option from the Actions drop-down of the "Ask A Librarian" plugin. We will need to **Enable** the plugin from here. Once enabled, refresh the OPAC page to see the new option on Koha's _navbar_ menu at the top edge of the OPAC.

# Reports

The plugin provides 2 sets of options for reports - (a) to show the entire feedback table contents **OR** (b) restricted between **_from_** and **_to_** dates. Further we have the option to view the report rendered as HTML on the browser or download it as a CSV *(comma separate value)* file. 

The report module is accessible via `More -> Reports -> Report plugins -> Ask A Librarian -> Actions -> Run report`.

# Uninstalling

The plugin can be uninstalled by selecting the `Uninstall` option from the `Actions` drop-down for the **Ask A Librarian** plugin. On uninstallation, you will lose all the feedback received by this plugin as the table with user feedback data will be deleted along with the code insertions made by the `Configure` option into the `OPACUserJS` and `OpacHeader` system preferences as well as the `UserDesignation` local user system preference.  

**HINT:** _On a production system you may wish to comment out the `uninstall()` sub-routine in the `AskALibrarian.pm` file._
