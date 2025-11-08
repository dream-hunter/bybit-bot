
#!/usr/bin/env perl

# Standard libs
use strict;
use IO::Async::Loop;
use Net::Async::WebSocket::Client;
use IO::Async::Timer::Periodic;
use JSON;
use POSIX;
use Data::Dumper;
use Digest::SHA qw(hmac_sha512_hex sha512_hex hmac_sha256_hex sha256_hex);

use feature qw( switch );
no warnings qw( experimental::smartmatch );
# Custom libs
use lib '.';
use lib './bybit-rest-api-pl/';
use ServiceSubs;
use GetConfig;
use APIHandlers;
use DataHandlers;
use TradeHandlers;
use MarketAnalysis;

logMessage("Program start.\n", 3, 5);
# Global variables
my $loglevel = 3;            # 1-5
my $heartbeat_interval = 60; # seconds
my $heartbeat;
# Handling config file
my $configfile = 'config.json';
my $config = GetConfig::configHandler($configfile, $loglevel);
# Handling ARGV
$config = DataHandlers::argvHandler($config, \@ARGV, $loglevel);
logMessage(sprintf("%s", Dumper $config), 4, $loglevel);
#################################
# Async Web Socket Client handler
#################################
while (1) {
    my $markets  = APIHandlers::getMarkets($config, $loglevel);
    logMessage(sprintf("Got %s markets.\n", scalar keys %{ $markets }), 3, $loglevel);
    my $feerate = undef;
    if (defined $config->{'API'}->{'apikey'} && $config->{'API'}->{'apisecret'}) {
        $feerate = APIHandlers::getFeeRate($config, $loglevel);
    }
    my $datapool = DataHandlers::initDataPool($config, $markets, $feerate, $loglevel);
    logMessage(sprintf("Set %s markets for trading.\n", scalar keys %{ $datapool }), 3, $loglevel);
    foreach my $marketname (keys %{ $datapool }) {
        logMessage(sprintf("Market %s trading info:\n", $marketname), 3, $loglevel);
#        logMessage(sprintf("%s", Dumper $datapool->{$marketname}->{'marketinfo'}), 3, $loglevel);
        logMessage(sprintf("%s", Dumper $datapool->{$marketname}->{'marketinfo'}->{'lotSizeFilter'}), 3, $loglevel);
        logMessage(sprintf("%s", Dumper $datapool->{$marketname}->{'feerate'}), 3, $loglevel);
    }

    my $timer  = undef;
    my $pinger = undef;
    my $req_id = {
        'pub'  => 0,
        'prv'  => 0
    };
    my $client = {
        'pub'  => 0,
        'prv'  => 0
    };
    my $loop   = undef;
    $heartbeat = {
        'pub' => time+$heartbeat_interval,
        'prv' => time+$heartbeat_interval
    };
    $timer = IO::Async::Timer::Periodic->new(
        interval=> 10,
        on_tick => sub {
# Heartbeat
            $heartbeat->{'err'} = undef;
            if ($heartbeat->{'pub'} < time) {
                logMessage("Public Heartbeat error " . $heartbeat->{'pub'} . " < ". time . "\n", 1, $loglevel);
                $heartbeat->{'err'} = 1;
            } else {
                logMessage("Public Heartbeat is fine " . $heartbeat->{'pub'} . " > ". time . "\n", 4, $loglevel);
            }
            if (defined $config->{API}->{apikey} && defined $config->{API}->{apisecret}) {
                if ($heartbeat->{'prv'} < time) {
                    logMessage("Private Heartbeat error " . $heartbeat->{'prv'} . " < ". time . "\n", 1, $loglevel);
                    $heartbeat->{'err'} = 1;
                } else {
                    logMessage("Private Heartbeat is fine " . $heartbeat->{'prv'} . " > ". time . "\n", 4, $loglevel);
                }
            } else {
                logMessage("Private Heartbeat disabled - no API key/secret defined\n", 2, $loglevel);
            }
            if (defined $heartbeat->{'err'} && $heartbeat->{'err'} == 1) {
                logMessage("Close connection with errors...\n", 1, $loglevel);
                $client->{'pub'}->close_now;
                $client->{'prv'}->close_now;
                $timer->stop;
                $pinger->stop;
                $loop->loop_stop;
            }
# Heartbeat is fine so you can handle streams data, send REST API requests, analyse and perform trading
            foreach my $marketname (keys %{ $datapool }) {
                my $analysis = MarketAnalysis::marketCheck($datapool->{$marketname}, $loglevel);
                if (defined $config->{'API'}->{'apikey'} && $config->{'API'}->{'apisecret'}) {
                    logMessage(sprintf("Market $marketname:\n%s", Dumper $analysis), 4, $loglevel);
                    $datapool->{$marketname} = TradeHandlers::tradeHandle($marketname, $datapool->{$marketname}, $analysis, $config->{'API'}, $loglevel);
                    exit 0;
                }
            }
        }
    );

    $pinger = IO::Async::Timer::Periodic->new(
        interval=> 20,
        on_tick => sub {
            foreach my $key ( keys %{ $client } ) {
                $req_id->{$key} ++;
                my $req_json = {
                    "req_id" => $req_id->{$key},
                    "op"     => "ping"
                };
                my $req = encode_json($req_json);
                logMessage("Sending ping msg: " . $req . "\n", 5, $loglevel);
                $client->{$key}->send_text_frame($req);
            }
        }
    );
# Public stream handler
    $client->{'pub'} = Net::Async::WebSocket::Client->new(
        on_text_frame => sub {
            my $data_pub = APIHandlers::wssFrameDecoder(@_, $loglevel);
# Market data
            if (defined $data_pub && defined $data_pub->{'topic'}) {
                my @topic = split(/\./, $data_pub->{'topic'});
                $datapool->{$topic[-1]} = DataHandlers::wssDataStreamHandler($datapool->{$topic[-1]}, $data_pub, $loglevel);
            }
# System data
            if (defined $data_pub && defined $data_pub->{'op'} && $data_pub->{'op'} eq "ping" && $data_pub->{'success'}) {
                $heartbeat->{'pub'} = time+$heartbeat_interval;
            }
# Here you can put any stuff, include subs, analyse etc
        }
    );
# Private stream handler
    $client->{'prv'} = Net::Async::WebSocket::Client->new(
        on_text_frame => sub {
            my $data_prv = APIHandlers::wssFrameDecoder(@_, $loglevel);
            if (defined $data_prv && defined $data_prv->{'op'} && $data_prv->{'op'} eq "pong") {
                $heartbeat->{'prv'} = time+$heartbeat_interval;
            }
# Here you can put any stuff, include subs, analyse etc
        }
    );

    $loop = IO::Async::Loop->new;

    $timer->start;
    $loop->add( $timer );

    $pinger->start;
    $loop->add( $pinger );

    $loop->add( $client->{'pub'} );
    $client->{'pub'}->connect(
       host => $config->{WSS}->{host},
       service => $config->{WSS}->{port},
       url => "wss://".$config->{WSS}->{host}.":".$config->{WSS}->{port}."/v5/public/spot",
    )->get;
    if (defined $config->{API}->{apikey} && defined $config->{API}->{apisecret}) {
        $loop->add( $client->{'prv'} );
        $client->{'prv'}->connect(
           host => $config->{WSS}->{host},
           service => $config->{WSS}->{port},
           url => "wss://".$config->{WSS}->{host}.":".$config->{WSS}->{port}."/v5/private",
        )->get;
    }
    logMessage("Connected, go ahead...\n", 3, $loglevel);
#################################
# Public subscription
#################################
    $req_id->{'pub'} ++;
    my @pub_args;
    foreach my $marketname (keys %{ $datapool }) {
#        push(@pub_args, "publicTrade.$marketname");
        push(@pub_args, "kline.5.$marketname");
        push(@pub_args, "kline.60.$marketname");
        push(@pub_args, "kline.M.$marketname");
        push(@pub_args, "tickers.$marketname");
    }
    my $datasend = {
        "req_id" => $req_id->{'pub'},
        "op" => "subscribe",
        "args" => [ @pub_args ]
    };
    print Dumper $datasend;
    $client->{'pub'}->send_text_frame( encode_json($datasend) );
#################################
# Private subscription
#################################
    if (defined $config->{API}->{apikey} && defined $config->{API}->{apisecret}) {
        logMessage("API Key/Secret defined. Attempting to send private request...\n", 3, $loglevel);
# auth
        $req_id->{'prv'} ++;
        my $expires = (time + 3) * 1000;
        my $signature = hmac_sha256_hex("GET/realtime$expires", $config->{API}->{apisecret});
        my $datasend = {
            'req_id' => $req_id->{'prv'},
            'op' => 'auth',
            'args' => [
                "$config->{API}->{apikey}",
                $expires,
                "$signature"
            ]
        };
        $client->{'prv'}->send_text_frame(encode_json($datasend));
# Request
        $req_id->{'prv'} ++;
        my $datasend = {
            "req_id" => $req_id->{'prv'},
            "op" => "subscribe",
            "args" => [
                "wallet"
            ]
        };
        $client->{'prv'}->send_text_frame(encode_json($datasend));
    } else {
        logMessage("API Key/Secret not defined.\n", 2, $loglevel);
    }
#################################
# Start main loop
#################################
    $loop->run;
#################################
# Wait and Restart
#################################
    logMessage("Wait 10 seconds before reconnect.\n", 2, $loglevel);
    sleep 10;
    logMessage("Start again...\n", 2, $loglevel);
}
#################################
# Subroutines
#################################
