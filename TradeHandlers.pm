package TradeHandlers;

require Exporter;

use strict;
use vars qw($VERSION @ISA @EXPORT);

use lib '.';
use lib './bybit-rest-api-pl/';

#use feature qw( switch );
#no warnings qw( experimental::smartmatch );

use POSIX;
use JSON;
use BybitAPI qw(rest_api);
use Storable qw(dclone);
use Data::Dumper;
use ServiceSubs;
use GetConfig;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(tradeHandle postSellOrder postBuyOrder);

sub tradeHandle {
    my $marketname = $_[0];
    my $datapool   = $_[1];
    my $analysis   = $_[2];
    my $api        = $_[3];
    my $loglevel   = $_[4];
    #if (defined $analysis->{'buy'} && $analysis->{'buy'} == 1) {
        my $orderId = postBuyOrder($datapool, $api, $loglevel);
        if (defined $orderId->{'orderId'}) {
            my $order = getOrdersRealTime($orderId->{'orderId'}, $marketname, $api, $loglevel);
            print Dumper $order;
            if (defined $order->{$orderId->{'orderId'}}) {
                logMessage("We have a buy!\nWriting order database for market $marketname...\n", 3, $loglevel);
                $datapool->{'orders'}->{'closed'}->{'buy'}->{$orderId->{'orderId'}} = $order->{$orderId->{'orderId'}};
                $datapool->{'analysis'}->{'orderlow'}  = DataHandlers::getOrderLow ($datapool->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                $datapool->{'analysis'}->{'orderhigh'} = DataHandlers::getOrderHigh($datapool->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                GetConfig::setConfig("DB-".uc($marketname).".json", $loglevel, $datapool->{'orders'});
            }
        } else {
            logMessage("Error: OrderId not defined\n", 2, $loglevel);
        }
    #}
}

sub postSellOrder {
    my $datapool = $_[0];
    my $api      = $_[1];
    my $loglevel = $_[2];
    print Dumper $datapool->{'marketinfo'};
    my $baseCoin = $datapool->{'marketinfo'}->{'baseCoin'};
    my $quoteCoin = $datapool->{'marketinfo'}->{'quoteCoin'};
    my $marketname = "$baseCoin$quoteCoin";
    logMessage(sprintf("!!!Wanna sell some %s!!!\n", $baseCoin), 3, $loglevel);
    my $endpoint = $api->{'url'} . "/v5/order/create";
    my $parameters = {
        "category"         => "spot",
        "symbol"           => $marketname,
        "side"             => "Buy",
        "orderType"        => "Limit",
        "qty"              => $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'minOrderQty'},
        "price"            => ($datapool->{'wss'}->{'tickers'}->{'lastPrice'} * 0.9)
    };
    my $method = "POST";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, $loglevel);
    print Dumper $result;

    return $datapool;
}

sub postBuyOrder {
    my $datapool = $_[0];
    my $api      = $_[1];
    my $loglevel = $_[2];
    my $baseCoin  = $datapool->{'marketinfo'}->{'baseCoin'};
    my $quoteCoin = $datapool->{'marketinfo'}->{'quoteCoin'};
    logMessage(sprintf("!!!Wanna buy some %s!!!\n", $baseCoin), 3, $loglevel);
    print Dumper $datapool->{'marketinfo'};
    my $marketname = "$baseCoin$quoteCoin";
    # calculate price
    my $pricePrecision = $datapool->{'marketinfo'}->{'priceFilter'}->{'tickSize'};
    my $price = ($datapool->{'wss'}->{'tickers'}->{'lastPrice'} * 0.9);
    $price = ceil($price / $pricePrecision) * $pricePrecision;
    $price = sprintf("%.8f", $price);
    # calculate min quantity
    my $basePrecision = $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'basePrecision'};
    my $qty = $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'minOrderAmt'} / $price;
    $qty = ceil($qty / $basePrecision) * $basePrecision;
    $qty = sprintf("%.8f", $qty);
    # prepare endpoint /gather parameters
    my $endpoint = $api->{'url'} . "/v5/order/create";
    my $parameters = {
        "category"         => "spot",
#        "timeInForce"      =>  "PostOnly",
        "timeInForce"      => "FOK",
        "symbol"           => $marketname,
        "marketUnit"       => "baseCoin",
        "side"             => "Buy",
        "orderType"        => "Limit",
        "qty"              => $qty,
        "price"            => $price
    };
    my $method = "POST";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, 10);
    logMessage(sprintf("%s", Dumper $result), 3, $loglevel);

    return $result;
}

sub getOrdersRealTime {
    my $orderId    = $_[0];
    my $marketname = $_[1];
    my $api        = $_[2];
    my $loglevel   = $_[3];
    my $result     = undef;
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
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, 10);
    $result = getHashedArray($result->{'list'}, 'orderId');
    #print Dumper $result;

    return $result
}

sub cancelAllOrders {
    my $datapool = $_[0];
    my $api      = $_[1];
    my $loglevel = $_[2];
    #print Dumper $datapool->{'marketinfo'};
    my $baseCoin  = $datapool->{'marketinfo'}->{'baseCoin'};
    my $quoteCoin = $datapool->{'marketinfo'}->{'quoteCoin'};
    my $marketname = "$baseCoin$quoteCoin";
    logMessage(sprintf("Cancel all orders for %s market:\n", $marketname), 3, $loglevel);
    my $endpoint = $api->{'url'} . "/v5/order/cancel-all";
    my $parameters = {
        "category"         => "spot",
        "symbol"           => $marketname,
    };
    my $method = "POST";
    my ($result, $ping) = rest_api($endpoint, $parameters, $api, $method, $loglevel);

    #print Dumper $result;

    return $result;
}

1;