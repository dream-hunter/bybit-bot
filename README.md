# bybit-bot

## Introduction

### Disclaimer.

Remember that:
1. All cryptocurrencies are high-risk assets. It's not intended for storing savings.
2. Never trust your money or access keys to strangers.
3. Always monitor, check, and count your money. Otherwise, you'll lose it.

### Advices

1. Restict access to server! Never use bot on servers with third party access! API key/secrets is unencrypted in config file.
2. Avoid to allow access even for configuration helpers.
3. Don't share any information about your trading server to avoid targeted network attacks.
4. Use SSHGuard and Firewalls to protect your server.
5. Don't store API keys/secrets on your home computer. Sometime generate new and delete/block old API keys.

### Links

[https://www.bybit.com/](https://www.bybit.com/) - Bybit main site;  
[https://www.bybit.com/invite?ref=9ELGDGB](https://www.bybit.com/invite?ref=9ELGDGB) - Referal link for new registration;  
[https://bybit-exchange.github.io/docs/](https://bybit-exchange.github.io/docs/) - API documentation  
[https://github.com/dream-hunter/bybit-bot](https://github.com/dream-hunter/bybit-bot) - Official bot project site  
[https://github.com/dream-hunter/bybit-rest-api-pl](https://github.com/dream-hunter/bybit-rest-api-pl) - REST API Library (required)  
[https://github.com/dream-hunter/bybit-wss-api-pl](https://github.com/dream-hunter/bybit-wss-api-pl) - WSS API Library (for developers)  

[service@it-answer.ru](mailto:service@it-answer.ru) - project support and feedback.  

### Description

### Requirements

1. Installed linux OS (ubuntu/centos etc)
2. Installed Perl with modules:
    * Daemon::Daemonize
    * Data::Dumper
    * DateTime
    * Digest::SHA
    * IO::Async::SSL
    * IO::Async::Loop
    * IO::Async::Timer::Periodic
    * JSON
    * LWP::Protocol::https
    * Net::Async::WebSocket::Client
    * POSIX
    * REST::Client
    * Storable
    * Time::HiRes
3. Installed git
4. Verified Bybit Account with activated Two-Factor Authentication
5. Synchronized time on your trading host
6. Internet access to Bybit WSS and API endpoints

## Installation Manual

### 1. Required software:
```
sudo dnf/apt/pkg install perl cpanminus git
```

### 2. Perl modules:
```
cpanm App::cpanoutdated
cpan-outdated -p | cpanm --sudo
cpanm JSON Daemon::Daemonize DateTime IO::Async::SSL LWP::Protocol::https Time::HiRes Digest::SHA Data::Dumper Storable POSIX Net::Async::WebSocket::Client IO::Async::Loop IO::Async::Timer::Periodic --sudo
sudo dnf/apt/pkg install perl-REST-Client
```

### 3. Download bybit-bot (as regular user):
```
cd ~/
git clone https://github.com/dream-hunter/bybit-bot.git
```

### 4. Downloading REST-API library
```
cd ~/bybit-bot
git clone https://github.com/dream-hunter/bybit-rest-api-pl.git
```

### 5. Prepare config file
```
cp config.json.example config.json
mcedit/nano/vi config.json
```
see more in config explanation section

### 6. Start program
> before start program you have to generate API key for trading - [https://www.bybit.com/app/user/api-management](https://www.bybit.com/app/user/api-management)
```
cd ~/bybit-bot
/usr/bin/env perl bybit-bot.pl -key=<your api key> -secret=<your api secret>
```

### 7. Background start
> To start program in background, you need to create directory for PID file and log-file.
```
mkdir /var/run/bybit-bot
chown username:groupname /var/run/bybit-bot
touch /var/log/bybit-bot.log
chown username:groupname /var/log/bybit-bot.log
cd ~/bybit-bot
/usr/bin/env perl bybit-bot.pl -key=<your api key> -secret=<your api secret> -daemonize
```
> Read how to rotate log files in your system to avoid problems with your disk space.

## Config explanation

System uses JSON format in config file. To run the bot, you need to copy config.json.example to config.json and/or edit some parameters.
There are three major sections: API, WSS and Markets.

### API

Basic configuration:
```
    "API" : {
        "url"       : "https://api.bybit.com"
    }
```

> [https://bybit-exchange.github.io/docs/v5/guide](https://bybit-exchange.github.io/docs/v5/guide) - Read more about REST API Endpoints  

This section contains information for API handlers.

"url" - API endpoint.

Known list of bybit API endpoints:
```
https://api.bybit.com
https://api.bytick.com
```

### WSS

> [https://bybit-exchange.github.io/docs/v5/ws/connect](https://bybit-exchange.github.io/docs/v5/ws/connect) - Read about WSS endpoints
Web socket uses to configure WSS endpoints.

Basic configuration:
```
    "WSS" : {
        "host" : "stream.bybit.com",
        "port" : "443"
    }
```

Known endpoints:
```
wss://stream.bybit.com:443
```

### Markets

Basic configuration:
```
"Markets" :
    {
        "BTCUSDT" : {
            "buy" : {
                "diffratelow"   : 0.15,
                "diffratehigh"  : 0.3,
                "minspread"     : -7,
                "emamethod"     : 0,
                "orderprice"    : 15,
                "enable"        : 1,
                "nextbuyorder"  : 0.975
            },
            "sell": {
                "nextsellorder" : 0.03
                "enable"        : 1,
            }
        }
    }
```

This section describes behaviour of each market. In process of trading bot compares current values with configuration. If all tests passed, it performs a buy or sell.

BUY/SELL section:

enable - possible values 0 or 1. You can enable or disable buy or sell section.

BUY section:

orderprice - Means how much money will be spent for each order. 15 - means ~15 USDT
minspread  - Price change in percent over the last 24 hours.
nextbuyorder - The bot will buy the order if the price drops to the specified value. For example first order was taken for 100 USDT. Next order will be for 97.5 USDT or less.
diffratelow/diffratehigh - The upper or lower price  in percent limit at which a purchase limit applies.

SELL section:

nextsellorder - The bot will sell the order if the price rises above the specified value.. For example order was taken for 100 USDT. This order will be sold for 103 USDT or more.


## ChangeLog

### 2025-12-20

- Added "-daemonize" lauch parameter. No need any software to launch program in background.
- Now program hides applied api key/secret
- Added SIG handling. Now you can stop process with command "killall -1 bybit-bot"

### 2025-12-01

- Fixed wrong handling of orders database;
- Changed streams registration to avoid receive an empty data;
- Improved instructions in readme.

### 2025-11-09

- finished buy and sell mechanism;
- beta-test.

### 2025-11-08

- First push to github.


### 2025-09

- Project created.
