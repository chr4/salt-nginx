{% set ssl_protocols = salt['pillar.get']('nginx:ssl_protocols', 'TLSv1.1 TLSv1.2 TLSv1.3') %}
{% set ssl_ciphers = salt['pillar.get']('nginx:ssl_ciphers', [
  'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:'
  'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-CHACHA20-POLY1305:',
  'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'
]|join ) %}
{% set ssl_session_cache = salt['pillar.get']('nginx:ssl_session_cache', 'shared:SSL:10m' ) %}
{% set ssl_prefer_server_ciphers = salt['pillar.get']('nginx:ssl_prefer_server_ciphers', 'on') %}
{% set ssl_stapling = salt['pillar.get']('nginx:ssl_stapling', 'off') %}
{% set ssl_stapling_verify = salt['pillar.get']('nginx:ssl_stapling_verify', 'off') %}
{% set ssl_session_tickets = salt['pillar.get']('nginx:ssl_session_tickets', 'off') %}

nginx-repo:
  pkgrepo.managed:
    - name: deb http://nginx.org/packages/mainline/ubuntu {{ grains['oscodename'] }} nginx
    - file: /etc/apt/sources.list.d/nginx.list
    - key_url: https://nginx.org/keys/nginx_signing.key
    - require_in:
      - pkg: nginx

nginx:
  pkg.installed: []
  service.running:
    - enable: true
    - watch:
      - pkg: nginx
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/conf.d/*.conf
      - module: validate-nginx-config
    - require:
      - cmd: systemctl daemon-reload

validate-nginx-config:
  module.wait:
    - name: nginx.configtest
    - watch:
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/conf.d/*.conf
      - file: /etc/systemd/system/nginx.service.d/service.conf

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://{{ tpldir }}/nginx.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - defaults:
        ssl_protocols: {{ ssl_protocols }}
        ssl_ciphers: {{ ssl_ciphers }}
        ssl_session_cache: {{ ssl_session_cache }}
        ssl_prefer_server_ciphers: {{ ssl_prefer_server_ciphers }}
        ssl_stapling: {{ ssl_stapling }}
        ssl_stapling_verify: {{ ssl_stapling_verify }}
        ssl_session_tickets: {{ ssl_session_tickets }}
    - require:
      - pkg: nginx

/etc/nginx/conf.d:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: nginx

# Delete default site
/etc/nginx/conf.d/default.conf:
  file.absent:
    - require:
      - pkg: nginx

# Ensure cache directory exists to be read for systemd hardening using ReadWritePaths
#
# NOTE: This is necessary as a workaround for Github Actions during testing only, so only touch the
# directory unless it's already existing.
/var/cache/nginx:
  file.directory:
    - name: /var/cache/nginx
    - user: root
    - group: root
    - mode: 640
    - require:
      - pkg: nginx
    - unless: test -d /var/cache/nginx


# Deploy hardened systemd service
/etc/systemd/system/nginx.service.d/service.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - source: salt://{{ slspath }}/nginx.service
    - require:
      - pkg: nginx
      - file: /var/cache/nginx
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /etc/systemd/system/nginx.service.d/service.conf
