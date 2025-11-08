package ServiceSubs;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Data::Dumper;
use POSIX;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(showcomparevalues compare_hashes getHashedArray logMessage);

sub showCompareValues {
    my $value_1 = $_[0];
    my $value_2 = $_[1];
    my $output;
    if ($value_1 > $value_2) {
        $output = "&arrowup";
    } elsif ($value_1 < $value_2) {
        $output = "&arrowdown";
    } else {
        $output = " ";
    }
    return $output;
}

sub compareHashes {
    my $hash1 = $_[0];
    my $hash2 = $_[1];
    my $output = 1;
    foreach my $key (keys %{ $hash1 }) {
        if ($hash1->{$key} != $hash2->{$key}) { $output = 0; }
    }
    return $output;
}

sub getHashedArray {
    my $array = $_[0];
    my $field = $_[1];
    my $result;
    foreach my $value (values @{ $array }) {
        if (defined $value->{$field}) {
            $result->{$value->{$field}} = $value;
            delete $result->{$value->{$field}}->{$field};
        }
    }
    return $result;
}

sub logMessage {
    my $string = $_[0];
    my $severity = $_[1];
    my $loglevel = $_[2];
    my @message = ('FATAL','ERROR','WARN','INFO','DEBUG','TRACE');
    if (defined $severity && $severity >= 0 && $severity <= $loglevel) {
        print strftime("%Y-%m-%d %H:%M:%S ", localtime);
        print "\[$message[$severity]\] ";
        print $string;
    }
};

1;
