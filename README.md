# Ubuntu Init Script

Ubuntu Server initialization script (compatible with 22.04 / 24.04).

## Usage

```bash
# Run without cloning:
sudo bash <(curl -fsSL https://raw.githubusercontent.com/recluse90s/ubuntu-init-script/master/init.sh)
# Run locally:
sudo bash init.sh
# Enjoy it!
```

## What it does

- System upgrade
- Chinese locale & timezone (Asia/Shanghai)
- TCP BBR congestion control
- Docker CE (official repository)
- Cleanup

## License

[Apache License 2.0](http://opensource.org/licenses/Apache-2.0)
