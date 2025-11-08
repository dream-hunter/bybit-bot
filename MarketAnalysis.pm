#!/usr/bin/env perl

package MarketAnalysis;

require Exporter;



use strict;
use lib '.';
#use lib './binance-rest-api-pl/';
#use BinanceAPI qw(rest_api);
use ServiceSubs qw(logMessage);
use POSIX;
use Data::Dumper;

use vars qw($VERSION @ISA @EXPORT);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(marketCheck buyCheck sellCheck);
#@EXPORT_OK;

sub marketCheck {
    my $datapool = $_[0];
    my $loglevel = $_[1];
    my $result;
    logMessage ("Check " . $datapool->{'marketinfo'}->{'baseCoin'} . $datapool->{'marketinfo'}->{'quoteCoin'} . " market:\n", 3, $loglevel);
    logMessage (sprintf ("\t1. Price: High: %s, Low: %s, Last: %s, Prev24H: %s\n",
        $datapool->{'wss'}->{'tickers'}->{'highPrice24h'},
        $datapool->{'wss'}->{'tickers'}->{'lowPrice24h'},
        $datapool->{'wss'}->{'tickers'}->{'lastPrice'},
        $datapool->{'wss'}->{'tickers'}->{'prevPrice24h'}
    ), 3, $loglevel);

    $result->{'buy'} = buyCheck($datapool, $loglevel);
    $result->{'sell'} = sellCheck($datapool, $loglevel);
#    print Dumper $result;
    return $result;
}

sub buyCheck {
    my $datapool = $_[0];
    my $loglevel = $_[1];
    my $result   = 1;

    logMessage(" BUY:\n", 3, $loglevel);
    if (defined $datapool->{'config'}->{'buy'}->{'enable'} && $datapool->{'config'}->{'buy'}->{'enable'} == 0) {
        logMessage("\t0. Buy diabled.\n", 2, $loglevel);
        $result = 0;
        return $result;
    }
# Odrerlow
    if (!defined $datapool->{'analysis'}->{'orderlow'}) {
        logMessage("\t0. There is no orders in database;\n", 2, $loglevel);
    } else {
        logMessage(sprintf("\t0. Order with lowest price: %s\n", $datapool->{'analysis'}->{'orderlow'}->{'price'}), 3, $loglevel);
    }
# Spread
    if (defined $datapool->{'wss'}->{'tickers'}->{'price24hPcnt'} && $datapool->{'config'}->{'buy'}->{'minspread'}) {
        my $spread = $datapool->{'wss'}->{'tickers'}->{'price24hPcnt'};
        if ($spread >= $datapool->{'config'}->{'buy'}->{'minspread'}) {
            logMessage(sprintf("\t1. Spread is fine (%s >= %s);\n", $spread, $datapool->{'config'}->{'buy'}->{'minspread'}), 3, $loglevel);
        } else {
            logMessage(sprintf("\t1. Spread is too low (%s < %s).\n", $spread, $datapool->{'config'}->{'buy'}->{'minspread'}), 3, $loglevel);
             $result = 0;
        }
    } else {
        logMessage("\t1. Spread values or config error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
# Trend
    my $lastprice = $datapool->{'wss'}->{'tickers'}->{'lastPrice'};
    if (defined $lastprice && defined $datapool->{'rest'}->{'klines'}->{5}->[0]) {
        if ($lastprice > $datapool->{'rest'}->{'klines'}->{'5'}->[0]->[1]) {
            logMessage(sprintf("\t2. Trend is fine (%s > %s);\n", $lastprice, $datapool->{'rest'}->{'klines'}->{'5'}->[0]->[1]), 3, $loglevel);
        } else {
            logMessage(sprintf("\t2. Trend is too low (%s < %s).\n", $lastprice, $datapool->{'rest'}->{'klines'}->{'5'}->[0]->[1]), 3, $loglevel);
            $result = 0;
        }
    } else {
        logMessage("\t2. Trend values error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
# Month Diffrate
    my $highprice_1M    = $datapool->{'analysis'}->{'klines'}->{'60'}->{'highPrice'};
    my $lowprice_1M     = $datapool->{'analysis'}->{'klines'}->{'60'}->{'lowPrice'};
    if (defined $highprice_1M && defined $lowprice_1M) {
        my $tradewindow  = $highprice_1M - $lowprice_1M;
        if (defined $datapool->{'config'}->{'buy'}->{'diffratehigh'} && defined $datapool->{'config'}->{'buy'}->{'diffratelow'}) {
            my $diffratehigh = $tradewindow * $datapool->{'config'}->{'buy'}->{'diffratehigh'};
            my $diffratelow  = $tradewindow * $datapool->{'config'}->{'buy'}->{'diffratelow'};
            if (($highprice_1M - $diffratehigh) > $lastprice) {
                logMessage(sprintf("\t3. 1 Month Diffrate is fine on top (%s > %s);\n", ($highprice_1M - $diffratehigh), $lastprice), 3, $loglevel);
            } else {
                logMessage(sprintf("\t3. 1 Month Diffrate is too high (%s < %s).\n", ($highprice_1M - $diffratehigh), $lastprice), 3, $loglevel);
                $result = 0;
            }
            if (($lowprice_1M + $diffratelow) < $lastprice) {
                logMessage(sprintf("\t4. 1 Month Diffrate is fine on bottom (%s < %s);\n", ($lowprice_1M + $diffratelow), $lastprice), 3, $loglevel);
            } else {
                logMessage(sprintf("\t4. 1 Month Diffrate is too low (%s > %s).\n", ($lowprice_1M + $diffratelow), $lastprice), 3, $loglevel);
                $result = 0;
            }
        } else {
            logMessage("\t3. Diffrate config error.\n", 1, $loglevel);
            $result = 0;
            return $result;
        }
    } else {
        logMessage("\t3. 1 Month Diffrate values error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
# 24hrs Diffrate
    my $highprice_24H    = $datapool->{'analysis'}->{'klines'}->{'5'}->{'highPrice'};
    my $lowprice_24H     = $datapool->{'analysis'}->{'klines'}->{'5'}->{'lowPrice'};
    if (defined $highprice_24H && defined $lowprice_24H) {
        my $tradewindow  = $highprice_24H - $lowprice_24H;
        if (defined $datapool->{'config'}->{'buy'}->{'diffratehigh'} && defined $datapool->{'config'}->{'buy'}->{'diffratelow'}) {
            my $diffratehigh = $tradewindow * $datapool->{'config'}->{'buy'}->{'diffratehigh'};
            my $diffratelow  = $tradewindow * $datapool->{'config'}->{'buy'}->{'diffratelow'};
            if (($highprice_24H - $diffratehigh) > $lastprice) {
                logMessage(sprintf("\t5. 24 Hours Diffrate is fine on top (%s > %s);\n", ($highprice_24H - $diffratehigh), $lastprice), 3, $loglevel);
            } else {
                logMessage(sprintf("\t5. 24 Hours Diffrate is too high (%s < %s).\n", ($highprice_24H - $diffratehigh), $lastprice), 3, $loglevel);
                $result = 0;
            }
            if (($lowprice_24H + $diffratelow) < $lastprice) {
                logMessage(sprintf("\t6. 24 Hours Diffrate is fine on bottom (%s < %s);\n", ($lowprice_24H + $diffratelow), $lastprice), 3, $loglevel);
            } else {
                logMessage(sprintf("\t6. 24 Hours Diffrate is too low (%s > %s).\n", ($lowprice_24H + $diffratelow), $lastprice), 3, $loglevel);
                $result = 0;
            }
        } else {
            logMessage("\t5. Diffrate config error.\n", 1, $loglevel);
            $result = undef;
            return $result;
        }
    } else {
        logMessage("\t5. 24 Hours Diffrate values error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
# EMA
    if (defined $datapool->{'analysis'}->{'klines'}->{'5'}->{'ema'} && defined $datapool->{'analysis'}->{'klines'}->{'60'}->{'ema'}) {
        my $ema5 = $datapool->{'analysis'}->{'klines'}->{'5'}->{'ema'};
        my $ema60 = $datapool->{'analysis'}->{'klines'}->{'60'}->{'ema'};
        if ($ema5 > $ema60) {
            logMessage(sprintf("\t7. EMA5 greater tnan EMA60 - good (%.2f > %.2f);\n", $ema5, $ema60), 3, $loglevel);
        } else {
            logMessage(sprintf("\t7. EMA5 lesser than EMA60 - bad (%.2f < %.2f).\n", $ema5, $ema60), 3, $loglevel);
            $result = 0;
        }
        if ($lastprice > $ema5) {
            logMessage(sprintf("\t8. Lastprice greater than EMA5 - good (%.2f > %.2f);\n", $lastprice, $ema5), 3, $loglevel);
        } else {
            logMessage(sprintf("\t8. Lastprice lesser than EMA5 - bad (%.2f < %.2f).\n", $lastprice, $ema5), 3, $loglevel);
            $result = 0;
        }
    } else {
        logMessage("\t6. EMA values error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
    return $result;
}

sub sellCheck {
    my $datapool = $_[0];
    my $loglevel = $_[1];
    my $result   = 1;

    logMessage(" SELL:\n", 3, $loglevel);
    if (defined $datapool->{'config'}->{'sell'}->{'enable'} && $datapool->{'config'}->{'sell'}->{'enable'} == 0) {
        logMessage("\t0. Sell diabled.\n", 2, $loglevel);
        $result = 0;
        return $result;
    }
# Orderlow
    my $lastprice = $datapool->{'wss'}->{'tickers'}->{'lastPrice'};
    if (!defined $datapool->{'analysis'}->{'orderlow'}) {
        logMessage("\t0. There is no orders in database - nothing to sell.\n", 2, $loglevel);
        $result = 0;
    } else {
        logMessage("\t0. There is orders in database;\n", 3, $loglevel);
    }
# Stoploss
    if (defined $datapool->{'config'}->{'sell'}->{'stoploss'}) {
        if ($lastprice < $datapool->{'analysis'}->{'orderlow'}->{'price'} * $datapool->{'config'}->{'sell'}->{'stoploss'}) {
            logMessage("\t1. Stoploss value exceeded.\n", 2, $loglevel);
            $result = 1;
            return $result;
        } else {
            logMessage("\t1. Stoploss value is fine;\n", 2, $loglevel);
        }
    } else {
        logMessage("\t1. Stop loss disabled;\n", 2, $loglevel);
    }
# Trend
    if (defined $lastprice && defined $datapool->{'rest'}->{'klines'}->{5}->[0]) {
        if ($lastprice > $datapool->{'rest'}->{'klines'}->{'5'}->[0]->[1]) {
            logMessage(sprintf("\t2. Trend is too high (%s > %s).\n", $lastprice, $datapool->{'rest'}->{'klines'}->{'5'}->[0]->[1]), 3, $loglevel);
            $result = 0;
        } else {
            logMessage(sprintf("\t2. Trend is fine (%s < %s);\n", $lastprice, $datapool->{'rest'}->{'klines'}->{'5'}->[0]->[1]), 3, $loglevel);
        }
    } else {
        logMessage("\t2. Trend values error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
# EMA
    if (defined $datapool->{'analysis'}->{'klines'}->{'5'}->{'ema'} && defined $datapool->{'analysis'}->{'klines'}->{'60'}->{'ema'}) {
        my $ema5 = $datapool->{'analysis'}->{'klines'}->{'5'}->{'ema'};
        my $ema60 = $datapool->{'analysis'}->{'klines'}->{'60'}->{'ema'};
        if ($ema5 > $ema60) {
            logMessage(sprintf("\t3. EMA5 greater tnan EMA60 - bad (%.2f > %.2f).\n", $ema5, $ema60), 3, $loglevel);
            $result = 0;
        } else {
            logMessage(sprintf("\t3. EMA5 lesser than EMA60 - good (%.2f < %.2f);\n", $ema5, $ema60), 3, $loglevel);
        }
        if ($lastprice > $ema5) {
            logMessage(sprintf("\t4. Lastprice greater than EMA5 - bad (%.2f > %.2f).\n", $lastprice, $ema5), 3, $loglevel);
            $result = 0;
        } else {
            logMessage(sprintf("\t4. Lastprice lesser than EMA5 - good (%.2f < %.2f);\n", $lastprice, $ema5), 3, $loglevel);
        }
    } else {
        logMessage("\t3. EMA values error.\n", 1, $loglevel);
        $result = undef;
        return $result;
    }
    return $result;
}

1;
