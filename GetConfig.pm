package GetConfig;

require Exporter;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use JSON        qw(from_json encode_json);
use POSIX;
use Data::Dumper;
use DateTime;
use DateTime::TimeZone::Local;

use lib '.';
use ServiceSubs;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(configHandler getConfig setConfig appendConfig);

sub configHandler {
    my $configfile = $_[0];
    my $loglevel   = $_[1];
    my $result     = getConfig($configfile, $loglevel);
    if (!defined $result) {
        logMessage( "Config file not found - exit.\n", 1, $loglevel);
        exit 0;
    } else { logMessage("Reading config file - ok;\n", 3, $loglevel); }
    if (!defined $result->{"WSS"} || !defined $result->{"WSS"}->{"host"} || !defined $result->{"WSS"}->{"port"}) {
        logMessage( "WSS config not found - exit.\n", 1, $loglevel);
        exit 0;
    } else { logMessage("WSS config found;\n", 3, $loglevel); }
    if (!defined $result->{"API"} || !defined $result->{"API"}->{"url"}) {
        logMessage( "API config not found - exit.\n", 1, $loglevel);
        exit 0;
    } else { logMessage("API config found;\n", 3, $loglevel); }
#    print Dumper $result;
    return $result;
}

sub getConfig {
    my $configfile = $_[0];
    my $loglevel = $_[1];
    my $config;

    if (-e $configfile) {
        my $json;
        {
            local $/;
            open my $fh, "<", "$configfile";
            $json = <$fh>;
            close $fh;
        }
        $config = from_json($json);
        logMessage ("Reading config from \'$configfile\'... - ok\n", 4, $loglevel);
    } else {
        logMessage ("Reading config from \'$configfile\'... - file does not exits\n", 1, $loglevel);
        $config = {};
        setConfig($configfile, $loglevel, $config);
    }
    return $config;
}

sub setConfig {
    my $configfile = $_[0];
    my $loglevel = $_[1];
    my $config = $_[2];
    local $/;
    open my $fh, ">", "$configfile";
    print $fh encode_json($config);
    close $fh;
    logMessage ("Rewriting config to $configfile... - ok\n", 3, $loglevel);
#    print Dumper $config;
    return $config;
}

sub appendConfig {
    my $configfile = $_[0];
    my $loglevel = $_[1];
    my $config = $_[2];
    local $/;
    open my $fh, ">>", "$configfile";
    my $dt = DateTime->now(time_zone => "local");
    print $fh "$dt : $config\n";
    close $fh;
    logMessage ("Append log to $configfile... - ok\n", 3, $loglevel);
#    print Dumper $config;
    return $config;
}

1;
