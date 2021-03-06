#!/usr/bin/perl -w
# ----------------------------------------------------------------------
# The Advanced Policy-Manager for IPS/IDS Sensors
# Copyright (C) 2010-2011, Edward Fjellskål <edwardfjellskaal@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# ----------------------------------------------------------------------

use IO::File;
use File::Path;
use Getopt::Long qw/:config auto_version auto_help/;
use strict;
use warnings;
use Polman::Common qw/:all/;
use Polman::Ruledb qw/:all/;
use Polman::Sensor qw/:all/;
use Polman::Search qw/:all/;
use Polman::Parser qw/:all/;

my $DEBUG             = undef;
my $VERBOSE           = undef;

=head1 NAME

polman - Advanced Policy Manager for IPS/IDS Sensors

=head1 VERSION

0.3.1

=head1 SYNOPSIS

 $ polman.pl [options]

 OPTIONS:

 --configure         : Enters the configuration menu
 -c <classtype>      : Search rules in field classtype
 -f <flowbit>        : Search rules in field flowbits
 -d <sid>            : Disable rule with sid <sid>
 -e <sid>            : Enable rule with sid <sid>
 -i <sensor>         : Sensor too work on
 -l <sid>            : Display rule with sid <sid>
 -m <catagory>       : Search rules by catagory
 -n                  : Search for new rules that are not added to the sensor
 -a                  : Auto enable new rules in its default state
 -o <1/0>            : Search rules by enabled(1) or disabled(0)
 -r <ruledb>         : RuleDB too work on
 -p <metadata>       : Search rules by metadata
 -s <msg>            : Search rules in field msg
 -u                  : Updates ruledb from its specified dirs
 -w <file>           : Write out all enabled rules for a sensor to <file>
 -v|--verbose        : Verbose output
 --debug             : Enables debug output

 EXAMPLES:
 # Enter a menu to configure RuleDBs and Sensors
 polman.pl --configure

 # Enables sid 31337 for sensor "mysensor" (if it is defined in the ruledb for the sensor):
 polman.pl -i mysensor -e 31337

 # Search for rules with classtype "attempted-user" and "exploit" in msg field:
 polman.pl -i mysensor -c "attempted-user" -s "exploit"

 # Search for rules with VRT policy defined (here: Security over Connectivity):
 polman.pl -i mysensor -p "policy security-ips drop"

=cut

my $RULEDB            = qq();
my $SENSOR            = qq();

my ($AUTO, $DSID, $ESID, $LSID, $UPDATE, $UPDATESENS, $STATUS, $SETUP) = 0;
my ($SEARCH_C, $SEARCH_F, $SEARCH_CAT, $SEARCH_P, $SEARCH_M, $SEARCH_NEW, $SEARCH_ENABLED, $WFILE) = undef;

# commandline overrides config & defaults
Getopt::Long::GetOptions(
    'debug'                  => \$DEBUG,
    'verbose|v=s'            => \$VERBOSE,
    'status'                 => \$STATUS,
    'configure'              => \$SETUP,
    'c=s'                    => \$SEARCH_C,
    'f=s'                    => \$SEARCH_F,
    'd=s'                    => \$DSID,
    'e=s'                    => \$ESID,
    'i=s'                    => \$SENSOR,
    'l=s'                    => \$LSID,
    'm=s'                    => \$SEARCH_CAT,
    'n'                      => \$SEARCH_NEW,
    'a'                      => \$AUTO,
    'o=s'                    => \$SEARCH_ENABLED,
    'p=s'                    => \$SEARCH_P,
    'r=s'                    => \$RULEDB,
    's=s'                    => \$SEARCH_M,
    'u'                      => \$UPDATE,
    'w'                      => \$UPDATESENS,
);

$SIG{"INT"}   = sub { gameover("INT") };
$SIG{"TERM"}  = sub { gameover("TERM") };
$SIG{"QUIT"}  = sub { gameover("QUIT") };
$SIG{"KILL"}  = sub { gameover("KILL") };

# Main
$| = 1; # flush stdout
print "[*] Starting main...\n" if ($VERBOSE||$DEBUG);

if ( defined $UPDATE ) {
   update_ruledb($RULEDB,$VERBOSE,$DEBUG);
}
elsif ( defined $STATUS ) {
   show_status($VERBOSE,$DEBUG);
}
elsif ( defined $SETUP) {
   run_config($VERBOSE,$DEBUG);
}
elsif ( defined $SEARCH_C || defined $SEARCH_M || defined $SEARCH_P ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           $SENSH = search_rules($SENSOR,$SENSH,$RULEDB,$RDBH,$SEARCH_C,$SEARCH_M,$SEARCH_P,$VERBOSE,$DEBUG);
       }
   }
}
elsif ( defined $SEARCH_CAT ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           $SENSH = search_rules_cat($SENSOR,$SENSH,$RULEDB,$RDBH,$SEARCH_CAT,$VERBOSE,$DEBUG);
       }
   }
}
elsif ( defined $SEARCH_F ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           $SENSH = search_rules_flow($SENSOR,$SENSH,$RULEDB,$RDBH,$SEARCH_F,$VERBOSE,$DEBUG);
       }
   }
}
elsif ( defined $SEARCH_NEW ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           $SENSH = search_new_rules($SENSOR,$SENSH,$RULEDB,$RDBH,$AUTO,$VERBOSE,$DEBUG);
       }
   }
}
elsif ( defined $SEARCH_ENABLED && ($SEARCH_ENABLED == 1 || $SEARCH_ENABLED == 0) ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           $SENSH = search_rules_enabled($SENSOR,$SENSH,$RULEDB,$RDBH,$SEARCH_ENABLED,$VERBOSE,$DEBUG);
       }
   }
}
elsif ( $ESID ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           my $ACTION = "current";
           $SENSH = sensor_enable_sid($ESID,$SENSOR,$SENSH,$RDBH,$RULEDB,$ACTION,$VERBOSE,(not defined $VERBOSE) ? 1 : $DEBUG);
       }
   }
}
elsif ( $DSID ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           $SENSH = sensor_disable_sid($DSID,$SENSOR,$SENSH,$RDBH,$RULEDB,$VERBOSE,(not defined $VERBOSE) ? 1 : $DEBUG);
       }
   }
}
elsif ( $LSID ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           print_rule($LSID,$SENSOR,$SENSH,$RULEDB,$RDBH,$VERBOSE,$DEBUG);
       }
   }
}
elsif ( $UPDATESENS ) {
   my ($RDBH) = init_statefile_ruledb();
   my ($SENSH) = init_statefile_sensordb();
   if (is_defined_sensor($SENSOR,$SENSH,$RDBH,$VERBOSE,$DEBUG) == 1) {
       my $RULEDB = $SENSH->{$SENSOR}->{'RULEDB'};
       if (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 1) {
           update_sensor_rules($SENSOR,$SENSH,$RDBH,$AUTO,$VERBOSE,$DEBUG);
           #print_rule($LSID,$SENSOR,$SENSH,$RULEDB,$RDBH,$VERBOSE,$DEBUG);
       }
   }
}else{
   print "[*] Nothing to do here... try with '-h'\n";
}

print "[*] Finished main...\n" if ($VERBOSE||$DEBUG);
exit;

=head1 FUNCTIONS

=head2 check_statfile_dir

 Check if the dir to source and save statefiles exists.
 Bail informally if not...

=cut

sub check_statfile_dir {
    if ( not -d "/var/lib/polman/" ) {
        print "[W] Statefile directory does not exist: /var/lib/polman/\n";
        if ( not mkdir("/var/lib/polman/", 0744) ) {
            print "[E] Could not create Statefile directory: /var/lib/polman/\n";
            print "[I] Make sure /var/lib/polman/ exists and is writable!\n";
            exit;
        } 
    }
}

=head2 init_statefile_ruledb

 Load persistant RuleDB if it exists.

=cut

sub init_statefile_ruledb {
    print "[*] Loading ruledb...\n" if ($VERBOSE||$DEBUG);
    use Polman::State RDB  => '/var/lib/polman/pm-rule.db';
    #use Polman::State RDB  => ['/var/lib/polman/pm-rule.db', readonly => 1 ];
    return ($RDB::RULEDB);
}

=head2 init_statefile_sensordb

 Load persistant SensorDB if it exists.

=cut

sub init_statefile_sensordb {
    print "[*] Loading sensordb...\n" if ($VERBOSE||$DEBUG);
    use Polman::State SENS => '/var/lib/polman/pm-sensor.db';
    #use Polman::State SENS => ['/var/lib/polman/pm-sensor.db', readonly => 1];
    return ($SENS::SENSORS);
}

=head2 init_statefile_sourcedb

 Load persistant SourceDB if it exists.

=cut

sub init_statefile_sourcedb {
    print "[*] Loading sourcedb...\n" if ($VERBOSE||$DEBUG);
    use Polman::State SO => '/var/lib/polman/pm-source.db';
    #use Polman::State SO => ['/var/lib/polman/pm-source.db', readonly => 1];
    return ($SO::SOURCE) if defined $SO::SOURCE; # defeat "possible typo" for the moment
    return ($SO::SOURCE);
}

=head2 update_ruledb

 Updates a ruledb with rules found in its specified path

=cut

sub update_ruledb {
    my ($RULEDB,$VERBOSE,$DEBUG) = @_;
    my ($RDBH) = init_statefile_ruledb();
    while (is_defined_ruledb($RULEDB,$RDBH,$VERBOSE,$DEBUG) == 0) {
        $RULEDB = choose_ruledb($RDBH,$VERBOSE,$DEBUG);
        gameover("EXIT") if (not defined $RULEDB);
    }
    $RDB::RULEDB = load_rulefiles_into_db($RULEDB,$RDBH,$VERBOSE,$DEBUG);
}

=head2 show_status

 This will display status about the setup

=cut

sub show_status {
    my ($VERBOSE,$DEBUG) = @_;
    my ($SENSH) = init_statefile_sensordb();
    my ($RDBH) = init_statefile_ruledb();
    my $count = 0;
    # Sensor info $SENS::SENSORS
    foreach my $SENS ( keys %$SENSH ) {
        next if not defined $SENS;
        next if $SENS eq "";
        if (is_defined_sensor($SENS,$SENSH,$RDBH,$VERBOSE,$DEBUG)) {
            show_sensor_status($SENS,$SENSH,$VERBOSE,$DEBUG);
        }
    }
    # Rule DB info $RDB::RULEDB
    foreach my $RDB (keys %$RDBH) {
        next if not defined $RDB;
        next if $RDB eq "";
        if (is_defined_ruledb($RDB,$RDBH,$VERBOSE,$DEBUG)) {
            show_ruledb_status($RDB,$RDBH,$VERBOSE,$DEBUG);
        }
    }
}

=head2 show_menu_main

 prints out the main menu

=cut

sub show_menu_main {
    print "\n";
    print " ************ Configuration Meny ************\n";
    print "  Item |  Description                        \n";
    print "    1  |  Edit Rule DB                       \n";
    print "    2  |  Edit Sensor                        \n";
#    print "    3  |  Edit rule source                   \n";
    print "    4  |  Status                             \n";
    print "   99  |  Save & Exit                        \n";
    print "Enter Item: ";
}

=head2 run_config

 This will go through configuration

=cut

sub run_config {
    my ($VERBOSE,$DEBUG) = @_;
    my $run = 0;

    while ($run == 0) {
        show_menu_main();
        my $RESP = <STDIN>;
        chomp $RESP;
        if ( $RESP eq "" or not $RESP =~ /\d+/ ) {
            print "[*] Not a valid entery!\n";
        }
        elsif ( $RESP == 1 ) {
            my ($RDBH) = init_statefile_ruledb();
            $RDBH = edit_ruledb($RDBH,$VERBOSE,$DEBUG);
            $RDB::RULEDB = $RDBH;
        }
        elsif ( $RESP == 2 ) {
            my ($SENSH) = init_statefile_sensordb();
            my ($RDBH) = init_statefile_ruledb();
            $SENSH = edit_sensor($SENSH,$RDBH,$VERBOSE,$DEBUG);
            $SENS::SENSORS = $SENSH;
        }
        elsif ( $RESP == 3 ) {
            #my ($SH) = init_statefile_sourcedb();
            #$SH = edit_rulesource($SH,$VERBOSE,$DEBUG);
            #$SO::SOURCE = $SH;
        }
        elsif ( $RESP == 4 ) {
            show_status();
        }
        elsif ( $RESP == 99 ) {
            $run = 1;
            return;
        } else {
            print "[*] $RESP is not a valid entery!\n";
        }
    }
}

sub gameover {
    my $sig = shift;
    print "\nGot signal $sig... Terminating...\n";
    exit;
}

=head1 AUTHOR

 Edward Fjellskaal <edwardfjellskaal@gmail.com>

=head1 LICENSE

 GPLv2 or later

=head1 Bugs

 Find them... and report back to $AUTHOR please...

=cut
