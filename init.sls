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

validate-nginx-config:
  module.wait:
    - name: nginx.configtest
    - watch:
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/conf.d/*.conf

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://{{ tpldir }}/nginx.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
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

# Deploy hardened systemd service
/lib/systemd/system/nginx.service:
  service.running:
    - name: nginx
    - enable: true
    - reload: true
    - watch:
      - file: /lib/systemd/system/nginx.service
      - file: /etc/nginx/nginx.conf
      - pkg: nginx
    - require:
      - file: /lib/systemd/system/nginx.service
      - cmd: systemctl daemon-reload
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://{{ tpldir }}/nginx.service.jinja
    - template: jinja
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /lib/systemd/system/nginx.service
