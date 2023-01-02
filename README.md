# Nginx salt formula

![Saltstack](https://github.com/chr4/salt-nginx/workflows/Saltstack/badge.svg)

Install and configure nginx.


## Available states

### init.sls

Install the `nginx` package from the official PPA.

To deploy sites, you need to put your configuration files in `/etc/nginx/conf.d` in another formula.


### letsencrypt.sls

Automatically install, configure and update TLS certificates using [letsencrypt](https://letsencrypt.org/).
It uses lightweight [dehydrated](https://dehydrated.io/) implementation in conjunction with a `systemd.timer`.

See `pillar.example` for documentation details.


## Notes

Tests currently fail, as it doesn't seem to be possible anymore to start `nginx` within Github Actions. Ideas welcome.
