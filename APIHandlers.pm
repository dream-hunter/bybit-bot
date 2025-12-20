#!/usr/bin/env perl

package APIHandlers;

require Exporter;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use lib '.';
use lib './bybit-rest-api-pl/';

use feature qw( switch );
no warnings qw( experimental::smartmatch );

use POSIX;
use JSON;
use BybitAPI qw(rest_api);
use Storable qw(dclone);
use Data::Dumper;
use ServiceSubs;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(
    getMarkets
    getKlines
    wssFrameDecoder
    getOrdersRealTime
    getOrdersHistory
    cancelAllOrders
);

sub getMarkets {
    my $config   = $_[0];
    my $loglevel = $_[1];
    my $result   = undef;
    my $ping     = undef;

    my $endpoint   = $config->{'API'}->{'url'} . "/v5/market/instruments-info";
    my $parameters = "category=spot";
    my $method     = "GET";
    logMessage("$method from $endpoint\?$parameters\n", 4, $loglevel);
    ($result, $ping) = rest_api("$endpoint", $parameters, undef, $method, $loglevel);
    if (defined $result) {
        $result = getHashedArray($result->{'list'},'symbol',$loglevel);
#        print Dumper $result;
    }
    return $result;
}

sub getFeeRate {
    my $config   = $_[0];
    my $loglevel = $_[1];
    my $result   = undef;
    my $ping     = undef;

    my $endpoint   = $config->{'API'}->{'url'} . "/v5/account/fee-rate";
    my $parameters = "category=spot";
    my $method     = "GET";
    logMessage("$method from $endpoint\?$parameters\n", 4, $loglevel);
    ($result, $ping) = rest_api("$endpoint", $parameters, $config->{'API'}, $method, $loglevel);
    if (defined $result) {
        $result = getHashedArray($result->{'list'},'symbol',$loglevel);
#        print Dumper $result;
    }
    return $result;
}

sub getKlines {
    my $config     = $_[0];
    my $symbol     = $_[1];
    my $interval   = $_[2];
    my $limit      = $_[3];
    my $loglevel   = $_[4];
    my $result     = undef;
    my $ping       = undef;

    my $endpoint   = $config->{'API'}->{'url'} . "/v5/market/kline";
    my $parameters = "category=spot&symbol=$symbol&interval=$interval";
    if (defined $limit && $limit > 0) {
        $parameters .= "&limit=$limit";
    }
    my $method     = "GET";
    logMessage("$method from $endpoint\?$parameters\n", 4, $loglevel);
    ($result, $ping) = rest_api("$endpoint", $parameters, undef, $method, $loglevel);
#    print Dumper $result;
    return $result;
}

sub wssFrameDecoder {
    my $self = $_[0];
    my $frame = $_[1];
    my $loglevel  = $_[2];
    my $decoded = decode_json($frame);
    if (defined $decoded->{'topic'}) {
        return $decoded;
    }
    if (defined $decoded->{'op'}) {
        given($decoded->{'op'}) {
            when(/ping/) {
                if ($decoded->{'success'}) {
                    logMessage("Pong frame for public channel received with success.\n", 4, $loglevel);
                } else {
                    logMessage("Pong frame for public channel received with no success.\n", 2, $loglevel);
                }
            }
            when(/pong/) {
                if ($decoded->{'args'}[0]) {
                    logMessage("Pong frame for private channel received with success.\n", 4, $loglevel);
                } else {
                    logMessage("Pong frame for private channel received with no success.\n", 2, $loglevel);
                }
            }
            when(/auth/) {
                if ($decoded->{'success'}) {
                    logMessage("Authenticated with success.\n", 3, $loglevel);
                } else {
                    logMessage("Authenticated with no success.\n", 2, $loglevel);
                }
            }
            when(/subscribe/) {
                if ($decoded->{'success'}) {
                    logMessage("Subscribed with success.\n", 3, $loglevel);
                } else {
                    logMessage("Subscribed with no success.\n", 2, $loglevel);
                }
            }
            default {
                logMessage("Unknown op-frame:\n", 2, $loglevel);
                print Dumper $decoded;
            }
        }
        return $decoded;
    }
    return undef;
}

sub getOrdersRealTime {
    my $orderId    = $_[0];
    my $marketname = $_[1];
    my $config     = $_[2];
    my $loglevel   = $_[3];
    my $result     = undef;
    my $api        = $config->{'API'};
    #print Dumper $orderId;
    logMessage("Getting order status:\n", 3, $loglevel);
    my $endpoint = $api->{'url'} . "/v5/order/realtime";
    my $parameters = "category=spot";
    if (defined $orderId) {
        $parameters .= "&orderId=".$orderId;
    }
    if (defined $marketname) {
        $parameters .= "&symbol=".$marketname;
    }
    my $method = "GET";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, $loglevel);
    $result = getHashedArray($result->{'list'}, 'orderId');

    return $result
}

sub getOrdersHistory {
    my $orderId    = $_[0];
    my $marketname = $_[1];
    my $config     = $_[2];
    my $loglevel   = $_[3];
    my $result     = undef;
    my $api        = $config->{'API'};
    #print Dumper $orderId;
    logMessage("Getting order history:\n", 3, $loglevel);
    my $endpoint = $api->{'url'} . "/v5/order/history";
    my $parameters = "category=spot";
    if (defined $orderId) {
        $parameters .= "&orderId=".$orderId;
    }
    if (defined $marketname) {
        $parameters .= "&symbol=".$marketname;
    }
    my $method = "GET";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, $loglevel);
    $result = getHashedArray($result->{'list'}, 'orderId');

    return $result
}

sub cancelAllOrders {
    my $marketname = $_[0];
    my $api        = $_[1];
    my $loglevel   = $_[2];
    logMessage(sprintf("Cancel all orders for %s market:\n", $marketname), 3, $loglevel);
    my $endpoint = $api->{'url'} . "/v5/order/cancel-all";
    my $parameters = {
        "category"         => "spot",
        "symbol"           => $marketname,
    };
    my $method = "POST";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, $loglevel);

    return $result;
}

sub postOrder {
    my $parameters = $_[0];
    my $api        = $_[1];
    my $loglevel   = $_[2];
    my $endpoint = $api->{'url'} . "/v5/order/create";
    my $method = "POST";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, $loglevel);
    logMessage(sprintf("%s", Dumper $result), 3, $loglevel);

    return $result;
}

1;