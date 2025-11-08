# bybit-bot

## Installation Manual

### 1. Required software:
```
sudo dnf/apt/pkg install perl cpanminus screen git
```

### 2. Perl modules:
```
cpanm App::cpanoutdated
cpan-outdated -p | cpanm --sudo
cpanm IO::Async Net::Async::WebSocket::Client JSON DateTime IO::Async::SSL LWP::Protocol::https --sudo
sudo dnf/apt/pkg install perl-REST-Client
```

### 3. Downloading bybit-bot
```
git clone https://github.com/dream-hunter/bybit-bot.git
```

### 4. Downloading REST-API library
```
cd bybit-bot
git clone https://github.com/dream-hunter/bybit-rest-api-pl.git
```

### 5. Prepare config file
```
cp config.json.example config.json
```

## ChangeLog

### 2025-11-08

- First push to github


### 2025-09

- Project created
