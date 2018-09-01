package Koha::Plugin::Com::L2C2Technologies::AskALibrarian;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;
use Koha::Email;
use Koha::DateUtils;
use MIME::Lite;
use Mail::Sendmail;
use Encode;
use Carp;

## Here we set our plugin version
our $VERSION = "0.9.1";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Ask A Librarian',
    author          => 'Indranil Das Gupta',
    date_authored   => '2018-08-22',
    date_updated    => '2018-09-01',
    minimum_version => '17.11.08.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements the AskALibrarian / reader feedback via OPAC feature',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('feedback');

    my $tablesetup = C4::Context->dbh->do( "
        CREATE TABLE IF NOT EXISTS $table (
            `feedback_id` INT( 11 ) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(255),
            `usertype` VARCHAR(50),
            `phone` VARCHAR(20), 
            `email` VARCHAR(100),
            `comment` mediumtext,
            `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `ipaddr` VARCHAR(40),
            primary key (feedback_id)
        ) ENGINE = INNODB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    " );

    my $prefsetup = C4::Context->set_preference( 'UserDesignation', '', 'List of user designations to use in AskALibrarian plugin', 'Free' );

    if ( $tablesetup && $prefsetup )
    {
        return 1;
    } 
    else {
        return 0;
    }

}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {

    my ( $self, $args ) = @_;

    $self->switch_askalibrarian();

    C4::Context->delete_preference( 'UserDesignation' ); 

    my $table = $self->get_qualified_table_name('feedback');

    return C4::Context->dbh->do("DROP TABLE $table");
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        $template->param( 'plugin_active' => $self->retrieve_data('plugin_enabled') );

        $self->output_html( $template->output() );
    }
    else {
        my $state_asklibrarian = $cgi->param( 'plugin_status' );
        if ( $state_asklibrarian eq 'enabled' ){
            $self->switch_askalibrarian(1);
        } 
        else {
            $self->switch_askalibrarian();
        }
        $self->go_home();
    }
}


## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    }
    else {
        $self->report_step2();
    }
}

sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'report-step1.tt' });

    $self->output_html( $template->output() );
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $table = $self->get_qualified_table_name('feedback');

    my $fromDate   = $cgi->param('datefrom');
    my $toDate     = $cgi->param('dateto');
    my $output     = $cgi->param('output');

    my $format_from_date = eval { output_pref({ dt => dt_from_string( $fromDate ), dateformat => 'iso', dateonly => 1 } ); };

    my $format_to_date = eval { output_pref({ dt => dt_from_string( $toDate ), dateformat => 'iso', dateonly => 1 } ); };

    my $query = "SELECT name, usertype, phone, email, comment, ipaddr, timestamp FROM $table ";

    if ( $fromDate && $toDate ) {
        $query .= " WHERE DATE( timestamp ) >= DATE( '$format_from_date' ) ";
        $query .= " AND DATE( timestamp ) <= DATE( '$format_to_date' ) ";
    }

    $query .= "ORDER BY feedback_id";

    my $sth = $dbh->prepare($query);
    $sth->execute();

    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push( @results, $row );
    }

    my $filename;
    if ( $output eq "csv" ) {
        print $cgi->header( -attachment => 'feedback.csv' );
        $filename = 'report-step2-csv.tt';
    }
    else {
        print $cgi->header();
        $filename = 'report-step2-html.tt';
    }

    my $template = $self->get_template({ file => $filename });

    $template->param(
        results_loop => \@results,
    );

    print $template->output();
}


## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    $self->tool_step1();

}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach

sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $name = $cgi->param('name');
    my $usertype = $cgi->param('usertype');
    my $phone = $cgi->param('phone');
    my $email = $cgi->param('email');
    my $comment = $cgi->param('comment');
    my $ipaddr = $cgi->remote_addr();
    my $datetime = localtime;

    my $letter = qq|The following feedback has been received. This will be processed by our team and you shall be notified as required.

    Name         : $name
    User type   : $usertype
    Phone        : $phone
    E-mail        : $email
    Comment   : $comment
    
    IP address  : $ipaddr
    Date/time   : $datetime
    
The Library Team|; 

    my $feedbackmail = Koha::Email->new();
    my %mail  = $feedbackmail->create_message_headers(
        {
            to      => $email,
            from    => C4::Context->preference( 'KohaAdminEmailAddress' ),
            subject => Encode::encode( "UTF-8", "Thank you for using the user feedback service" ),
            message => Encode::encode( "UTF-8", $letter ),
            contenttype => 'text/plain; charset="utf-8"',
        }
    );
    unless( Mail::Sendmail::sendmail(%mail) ) {
        carp $Mail::Sendmail::error;
        return { error => $Mail::Sendmail::error };
    };
    my $table = $self->get_qualified_table_name('feedback');

    my $testcase =  C4::Context->dbh->do( "
        INSERT INTO $table (name, usertype, phone, email, comment, ipaddr) VALUES ( '$name', '$usertype', '$phone', '$email', '$comment', '$ipaddr' ); 
    " );

   print $cgi->header(
        {
            -type     => 'application/json',
            -charset  => 'UTF-8',
            -encoding => "UTF-8"
        }); 

   my  $feedback_status_json = ( C4::Context->dbh->err ) ? 
       qq|{ "status":"error" }| :
       qq|{ "status":"success" }|;     

   print $feedback_status_json;

}

sub switch_askalibrarian {
    my ($self, $activate) = @_;

    my $opacuserjs = C4::Context->preference('opacuserjs');
    $opacuserjs =~ s/\n\/\* INKOLT_NAVOPT.*INKOLT_NAVOPT \*\///gs;
    $opacuserjs =~ s/\n\/\* INKOLT_MODALJS.*INKOLT_MODALJS \*\///gs;
   

    my $opacheader = C4::Context->preference('opacheader');
    $opacheader =~ s/\n<!-- INKOLT_FEEDBACK_BEGIN (.|\s)*? INKOLT_FEEDBACK_END -->//g;

    if ($activate) {
        my $template = $self->get_template( { file => 'activate_asklibrarian.tt' } );
        my $activate_askalibrarian_js = $template->output();

        my $modaljstemplate = $self->get_template( { file => 'modaljs.tt' } );
        my $modaljs = $modaljstemplate->output();

        $activate_askalibrarian_js = qq|\n/* INKOLT_NAVOPT - JS to activate AskALibrarian plugin */
/* TOUCH ONLY IF YOU KNOW WHAT YOU ARE DOING */|
        . $activate_askalibrarian_js
        . q|/* INKOLT_NAVOPT */|
        . qq|\n/* INKOLT_MODALJS - JS handler for modal submit */
/* TOUCH ONLY IF YOU KNOW WHAT YOU ARE DOING */\n|
        . $modaljs
        . q|/* INKOLT_MODALJS */|;

        $opacuserjs .= $activate_askalibrarian_js;
        C4::Context->set_preference( 'opacuserjs', $opacuserjs );

        my $modaltemplate = $self->get_template( { file => 'feedbackmodal.tt' } );
        my $activate_feedbackmodal = $modaltemplate->output();

        $activate_feedbackmodal = qq|\n<!-- INKOLT_FEEDBACK_BEGIN -->
<!-- TOUCH ONLY IF YOU KNOW WHAT YOU ARE DOING -->|
        . $activate_feedbackmodal
        . q|<!-- INKOLT_FEEDBACK_END -->|;

        $opacheader .= $activate_feedbackmodal;
        C4::Context->set_preference( 'opacheader', $opacheader );       
        
        $self->store_data(
            {
                plugin_enabled	=> '1',
            }
        );
    }
    else {
        C4::Context->set_preference( 'opacuserjs', $opacuserjs );
        C4::Context->set_preference( 'opacheader', $opacheader );
        $self->store_data(
            {
                plugin_enabled  => '0',
            }
        );
    }
}

1;
