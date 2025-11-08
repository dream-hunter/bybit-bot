#!/usr/bin/env perl

package DataHandlers;

require Exporter;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use lib '.';
use lib './bybit-rest-api-pl/';

use feature qw( switch );
no warnings qw( experimental::smartmatch );

use POSIX;
use GetConfig;
use BybitAPI qw(rest_api);
use Storable   qw(dclone);
use Data::Dumper;
use ServiceSubs;
use APIHandlers;
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(
    argvHandler
    initDataPool
    getOrderHigh
    getOrderLow
    wssDataStreamHandler
);

sub argvHandler {
    my $config   = $_[0];
    my @argv     = $_[1];
#    print Dumper $argv[0];
    my $loglevel = $_[2];
    foreach my $value (values @{ $argv[0] }) {
        my @param = split("=",$value);
        given($param[0]) {
            when(/-key/) {
                $config->{'API'}->{'apikey'} = $param[1];
            }
            when(/-secret/) {
                $config->{'API'}->{'apisecret'} = $param[1];
            }
            default {
                logMessage("Unknown parameter: \'$value\' - skip\n", 2, $loglevel);
            }
        }
    }
    return $config;
}

sub initDataPool {
    my $config   = $_[0];
    my $markets  = $_[1];
    my $feerate  = $_[2];
    my $loglevel = $_[3];
    my $datapool = undef;
    logMessage("Check markets info compare to config file\n", 3, $loglevel);
    foreach my $marketname (keys %{ $config->{'Markets'} }) {
        logMessage("$marketname:\n", 3, $loglevel);
        if (defined $markets->{$marketname} && $markets->{$marketname}->{'status'} eq 'Trading') {
            logMessage("\t1. Marketname defined and status - \'".$markets->{$marketname}->{'status'}."\';\n", 3, $loglevel);
            $datapool->{$marketname}->{'config'} = $config->{Markets}->{$marketname};
            $datapool->{$marketname}->{'marketinfo'} = $markets->{$marketname};
            if (defined $feerate->{$marketname}) {
                $datapool->{$marketname}->{'feerate'} = $feerate->{$marketname};
            }
            $datapool->{$marketname}->{'orders'} = getConfig("DB-".uc($marketname).".json", $loglevel);
            if (defined $datapool->{$marketname}->{'orders'}) {
                logMessage("\t2. Reading orders from database - ok\n", 3, $loglevel);
                $datapool->{$marketname}->{'analysis'}->{'orderlow'} = getOrderLow($datapool->{$marketname}->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                $datapool->{$marketname}->{'analysis'}->{'orderhigh'} = getOrderHigh($datapool->{$marketname}->{'orders'}->{'closed'}->{'buy'}, $loglevel);
            } else {
                logMessage("\t2. Reading orders from database - error\n", 1, $loglevel);
            }
            my $interval = 5;
            my $limit    = 289;
            my $klines = getKlines($config, $marketname, $interval, $limit, $loglevel);
            if (defined $klines->{'list'}) {
                shift(@{ $klines->{'list'} });
                $datapool->{$marketname}->{'rest'}->{'klines'}->{$interval} = $klines->{'list'};
                $datapool->{$marketname}->{'analysis'}->{'klines'}->{$interval} = getKlinesAnalysis($klines->{'list'}, $config->{'Markets'}->{$marketname}, $loglevel);
                logMessage("\t3. Reading klines ($interval) from database - ok\n", 3, $loglevel);
            } else {
                logMessage("\t3. Reading klines ($interval) from database - error\n", 1, $loglevel);
            }
            $interval = 60;
            $limit    = 721;
            $klines = getKlines($config, $marketname, $interval, $limit, $loglevel);
            if (defined $klines->{'list'}) {
                shift(@{ $klines->{'list'} });
                $datapool->{$marketname}->{'rest'}->{'klines'}->{$interval} = $klines->{'list'};
                $datapool->{$marketname}->{'analysis'}->{'klines'}->{$interval} = getKlinesAnalysis($klines->{'list'}, $config->{'Markets'}->{$marketname}, $loglevel);
                logMessage("\t4. Reading klines ($interval) from database - ok\n", 3, $loglevel);
            } else {
                logMessage("\t4. Reading klines ($interval) from database - error\n", 1, $loglevel);
            }
            $interval = "M";
            $limit    = 13;
            $klines = getKlines($config, $marketname, $interval, $limit, $loglevel);
            if (defined $klines->{'list'}) {
                shift(@{ $klines->{'list'} });
                $datapool->{$marketname}->{'rest'}->{'klines'}->{$interval} = $klines->{'list'};
                $datapool->{$marketname}->{'analysis'}->{'klines'}->{$interval} = getKlinesAnalysis($klines->{'list'}, $config->{'Markets'}->{$marketname}, $loglevel);
                logMessage("\t5. Reading klines ($interval) from database - ok\n", 3, $loglevel);
            } else {
                logMessage("\t5. Reading klines ($interval) from database - error\n", 1, $loglevel);
            }
        } else {
            logMessage("\t1. Status - \'".$markets->{$marketname}->{'status'}."\' - skip.\n", 1, $loglevel);
        }
    }
    return $datapool;
}

sub getKlinesAnalysis {
    my $klines    = $_[0];
    my $config    = $_[1];
    my $loglevel  = $_[2];
    my $result    = undef;
    my $alpha     = 0.125;
    foreach my $kline (reverse @{ $klines }) {
# High price
        if (!defined $result->{'highPrice'} || $result->{'highPrice'} < $kline->[2]) {
            $result->{'highPrice'} = $kline->[2];
        }
# Low price
        if (!defined $result->{'lowPrice'} || $result->{'lowPrice'} > $kline->[3]) {
            $result->{'lowPrice'} = $kline->[3];
        }
# Summary volume
        if (defined $result->{'sumVolume'}) {
            $result->{'sumVolume'} += $kline->[5];
        } else {
            $result->{'sumVolume'} = $kline->[5];
        }
# EMA
        if (defined $result->{'ema'} && $result->{'ema'} != 0) {
            if (!defined $config->{'buy'}->{'emamethod'} || $config->{'buy'}->{'emamethod'} == 0) {
                $result->{'ema'} = $alpha * $kline->[4] + (1-$alpha) * $result->{'ema'};
            } else {
#                $result->{'ema'} = $result->{'ema'} + 2 * ($kline->[4] - $result->{'ema'});
                $result->{'ema'} = ($result->{'ema'} + $kline->[4])/2;
            }
        } else {
            $result->{'ema'} = $kline->[4];
        }
    }

    return $result;
}

sub getOrderLow {
    my $orders   = $_[0];
    my $loglevel = $_[1];
    my $result   = undef;
    foreach my $order (values %{ $orders }) {
        if (!defined $result || $result->{'price'} > $order->{'price'}) {
            $result = dclone $order;
        }
    }
    return $result;
}

sub getOrderHigh {
    my $orders   = $_[0];
    my $loglevel = $_[1];
    my $result   = undef;
    foreach my $order (values %{ $orders }) {
        if (!defined $result || $result->{'price'} < $order->{'price'}) {
            $result = dclone $order;
        }
    }
    return $result;
}

sub wssDataStreamHandler {
    my $datapool   = $_[0];
    my $decoded    = $_[1];
    my $loglevel   = $_[2];
    my @topic      = split (/\./, $decoded->{'topic'});

    logMessage("Handling data with topic \'$topic[0]\' for market $topic[-1].\n", 4, $loglevel);

    given($topic[0]) {
        when(/tickers/) {
            logMessage(sprintf ("%s %s %s %s\n",
                $decoded->{'data'}->{'symbol'},
                $decoded->{'data'}->{'lastPrice'},
                $decoded->{'data'}->{'highPrice24h'},
                $decoded->{'data'}->{'lowPrice24h'},
            ), 5, $loglevel);
            $datapool->{'wss'}->{'tickers'} = $decoded->{'data'};
        }
        when(/publicTrade/) {
            foreach my $data ( @{ $decoded->{'data'} } ) {
                logMessage(sprintf ("\t%s: %s %s %s\n",
                    $data->{'S'},
                    $data->{'p'},
                    $data->{'v'},
                    $data->{'L'},
                ), 5, $loglevel);
            }
        }
        when(/kline/) {
            foreach my $data ( @{ $decoded->{'data'} } ) {
                $datapool->{'wss'}->{'klines'}->{$topic[1]} = $data;
                logMessage(sprintf ("\t%s from %s to %s: %s %s %s %s\n",
                    $decoded->{'topic'},
                    strftime("%Y-%m-%d %H:%M:%S", localtime(int($data->{'start'}/1000))),
                    strftime("%Y-%m-%d %H:%M:%S", localtime(int($data->{'end'}/1000))),
                    $data->{'open'},
                    $data->{'close'},
                    $data->{'high'},
                    $data->{'low'}
                ), 5, $loglevel);
                if ($data->{'confirm'}) {
                    my $kline = [
                        $data->{'start'},
                        $data->{'open'},
                        $data->{'high'},
                        $data->{'low'},
                        $data->{'close'},
                        $data->{'volume'},
                        $data->{'turnover'}
                    ];
                    pop(@{ $datapool->{'rest'}->{'klines'}->{$topic[1]} });
                    unshift (@{ $datapool->{'rest'}->{'klines'}->{$topic[1]} }, $kline);
                    $datapool->{'analysis'}->{'klines'}->{$topic[1]} = getKlinesAnalysis($datapool->{'rest'}->{'klines'}->{$topic[1]}, $datapool->{'config'}, $loglevel);
                }
            }
        }
        default {
            print Dumper $decoded;
        }
    }
    return $datapool;
}

1;
