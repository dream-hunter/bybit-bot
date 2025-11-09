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
#use BybitAPI qw(rest_api);
use Storable qw(dclone);
use Data::Dumper;
use APIHandlers;
use ServiceSubs;
use GetConfig;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(tradeHandle postSellOrder postBuyOrder);

sub tradeHandle {
    my $marketname = $_[0];
    my $datapool   = $_[1];
    my $analysis   = $_[2];
    my $config     = $_[3];
    my $loglevel   = $_[4];
    if (defined $analysis->{'sell'} && $analysis->{'sell'} == 1) {
        my $orderId = createSellOrder($marketname, $datapool, $config, $loglevel);
        if (defined $orderId->{'orderId'}) {
            my $order = APIHandlers::getOrdersRealTime($orderId->{'orderId'}, $marketname, $config, $loglevel);
            logMessage(sprintf("Created order:\n%s", Dumper $order->{$orderId->{'orderId'}}), 4, $loglevel);

            if (defined $order->{$orderId->{'orderId'}} && $order->{$orderId->{'orderId'}}->{'orderStatus'} eq 'Filled') {
                logMessage("!!!We have a sell!!!\nWriting order database for market $marketname...\n", 3, $loglevel);
                delete $datapool->{'orders'}->{'closed'}->{'buy'}->{$orderId->{'orderId'}};
                $datapool->{'analysis'}->{'orderlow'}  = DataHandlers::getOrderLow ($datapool->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                $datapool->{'analysis'}->{'orderhigh'} = DataHandlers::getOrderHigh($datapool->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                GetConfig::setConfig("DB-".uc($marketname).".json", $loglevel, $datapool->{'orders'});

                # exit 0;
            } else {
                logMessage("Order was not filled.\n", 3, $loglevel);
            }
        } else {
            logMessage("Error: OrderId not defined.\n", 2, $loglevel);
        }
    }
    if (defined $analysis->{'buy'} && $analysis->{'buy'} == 1) {
        my $orderId = createBuyOrder($marketname, $datapool, $config, $loglevel);
        if (defined $orderId->{'orderId'}) {
            my $order = APIHandlers::getOrdersRealTime($orderId->{'orderId'}, $marketname, $config, $loglevel);
            logMessage(sprintf("Created order:\n%s", Dumper $order->{$orderId->{'orderId'}}), 4, $loglevel);

            if (defined $order->{$orderId->{'orderId'}} && $order->{$orderId->{'orderId'}}->{'orderStatus'} eq 'Filled') {
                logMessage("!!!We have a buy!!!\nWriting order database for market $marketname...\n", 3, $loglevel);
                $datapool->{'orders'}->{'closed'}->{'buy'}->{$orderId->{'orderId'}} = $order->{$orderId->{'orderId'}};
                $datapool->{'analysis'}->{'orderlow'}  = DataHandlers::getOrderLow ($datapool->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                $datapool->{'analysis'}->{'orderhigh'} = DataHandlers::getOrderHigh($datapool->{'orders'}->{'closed'}->{'buy'}, $loglevel);
                GetConfig::setConfig("DB-".uc($marketname).".json", $loglevel, $datapool->{'orders'});

                # exit 0;
            } else {
                logMessage("Order was not filled.\n", 3, $loglevel);
            }
        } else {
            logMessage("Error: OrderId not defined.\n", 2, $loglevel);
        }
    }
    return $datapool;
}

sub createBuyOrder {
    my $marketname = $_[0];
    my $datapool   = $_[1];
    my $config     = $_[2];
    my $loglevel   = $_[3];

    my $api            = $config->{'API'};
    my $baseCoin       = $datapool->{'marketinfo'}->{'baseCoin'};
    my $quoteCoin      = $datapool->{'marketinfo'}->{'quoteCoin'};
    my $pricePrecision = $datapool->{'marketinfo'}->{'priceFilter'}->{'tickSize'};
    my $basePrecision  = $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'basePrecision'};
    my $minOrderAmt    = $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'minOrderAmt'};

    logMessage(sprintf("!!!Wanna buy some %s!!!\n", $baseCoin), 3, $loglevel);
    print Dumper $datapool->{'marketinfo'};
    # calculate price
    my $price = $datapool->{'wss'}->{'tickers'}->{'lastPrice'};
    $price = ceil($price / $pricePrecision) * $pricePrecision;
    $price = sprintf("%.8f", $price);
    # calculate quantity
    my $qty = $minOrderAmt / $price;
    if (defined $datapool->{'config'}->{'buy'}->{'orderprice'}) {
        my $confqty = $datapool->{'config'}->{'buy'}->{'orderprice'} / $price;
        if ($confqty > $qty) {
            $qty = $confqty;
        }
    }
    $qty = ceil($qty / $basePrecision) * $basePrecision;
    $qty = sprintf("%.8f", $qty);
    # prepare endpoint /gather parameters
    my $parameters = {
        "category"         => "spot",
        "timeInForce"      => "FOK",
        "symbol"           => $marketname,
        "marketUnit"       => "baseCoin",
        "side"             => "Buy",
        "orderType"        => "Limit",
        "qty"              => $qty,
        "price"            => $price
    };
    my $result = APIHandlers::postOrder($parameters, $api, $loglevel);
    logMessage(sprintf("%s", Dumper $result), 3, $loglevel);

    return $result;
}

sub createSellOrder {
    my $marketname = $_[0];
    my $datapool   = $_[1];
    my $config     = $_[2];
    my $loglevel   = $_[3];

    my $api            = $config->{'API'};
    my $baseCoin       = $datapool->{'marketinfo'}->{'baseCoin'};
    my $quoteCoin      = $datapool->{'marketinfo'}->{'quoteCoin'};
    my $pricePrecision = $datapool->{'marketinfo'}->{'priceFilter'}->{'tickSize'};
    my $basePrecision  = $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'basePrecision'};
    my $minOrderAmt    = $datapool->{'marketinfo'}->{'lotSizeFilter'}->{'minOrderAmt'};
    my $orderlow       = $datapool->{'analysis'}->{'orderlow'};

    #print Dumper $orderlow;
    #print "$baseCoin\n";
    #exit 0;
    logMessage(sprintf("!!!Wanna sell %s!!!\n", $baseCoin), 3, $loglevel);
    # calculate price
    my $price = $datapool->{'wss'}->{'tickers'}->{'lastPrice'};
    $price = ceil($price / $pricePrecision) * $pricePrecision;
    $price = sprintf("%.8f", $price);
    # calculate quantity
    my $qty = $orderlow->{'cumExecQty'} - $orderlow->{'cumFeeDetail'}->{$baseCoin};
    $qty = floor($qty / $basePrecision) * $basePrecision;
    $qty = sprintf("%.8f", $qty);
    # prepare endpoint /gather parameters
    my $parameters = {
        "category"         => "spot",
        "timeInForce"      => "FOK",
        "symbol"           => $marketname,
        "marketUnit"       => "baseCoin",
        "side"             => "Sell",
        "orderType"        => "Limit",
        "qty"              => $qty,
        "price"            => $price
    };
    my $result = APIHandlers::postOrder($parameters, $api, 10);
    logMessage(sprintf("%s", Dumper $result), 3, $loglevel);

    return $result;
}

1;