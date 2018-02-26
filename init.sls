# Use official PPA
nginx_repo:
  pkgrepo.managed:
    - name: deb http://nginx.org/packages/mainline/ubuntu xenial nginx
    - file: /etc/apt/sources.list.d/nginx.list
    - key_url: https://nginx.org/keys/nginx_signing.key
    - require_in:
      - pkg: nginx

nginx:
  pkg.installed:
    - pkgs: [nginx]
  service.running:
    - enable: true
    - watch:
      - pkg: nginx
      - file: /etc/nginx/nginx.conf

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://{{ slspath }}/nginx.conf.jinja
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
