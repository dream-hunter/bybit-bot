# bybit-bot

## Introduction

### **Disclaimer**. Remember that:

1. All cryptocurrencies are high-risk assets. It's not intended for storing savings.
2. Never trust your money or access keys to strangers.
3. Always monitor, check, and count your money. Otherwise, you'll lose it.

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
    * JSON
    * DateTime
    * IO::Async::SSL
    * LWP::Protocol::https
    * REST::Client
    * Time::HiRes
    * Digest::SHA
    * Data::Dumper
    * Storable
    * POSIX
    * Net::Async::WebSocket::Client
    * IO::Async::Loop
    * IO::Async::Timer::Periodic
3. Installed git
4. Verified Bybit Account with activated Two-Factor Authentication
5. Synchronized time on your host
6. Internet access to Bybit WSS and API endpoints

## Installation Manual

### 1. Required software:
```
sudo dnf/apt/pkg install perl cpanminus screen git
```

### 2. Perl modules:
```
cpanm App::cpanoutdated
cpan-outdated -p | cpanm --sudo
cpanm JSON DateTime IO::Async::SSL LWP::Protocol::https Time::HiRes Digest::SHA Data::Dumper Storable POSIX Net::Async::WebSocket::Client IO::Async::Loop IO::Async::Timer::Periodic --sudo
sudo dnf/apt/pkg install perl-REST-Client
```

### 3. Downloading bybit-bot (as regular user):
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
nano config.json
```

### 6. Start program
> before start program you have to generate API key for trading - [https://www.bybit.com/app/user/api-management](https://www.bybit.com/app/user/api-management)
```
cd ~/bybit-bot
/usr/bin/env perl bybit-bot.pl -key=<your api key> -secret=<your api secret>
```

### 7. Background start
Background start not implemented yet, but this planned in future releases. For now you can use Linux software such as screen:
```
cd ~/bybit-bot/ && /usr/bin/screen -dmSL "bybit-bot" /usr/bin/env perl bybit-bot.pl -key=<your api key> -secret=<your api secret>
```

## ChangeLog

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
