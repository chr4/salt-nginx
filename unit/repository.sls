nginx-unit-repo:
  pkgrepo.managed:
    - name: deb https://packages.nginx.org/unit/ubuntu/ {{ grains['oscodename'] }} unit
    - file: /etc/apt/sources.list.d/nginx-unit.list
    - key_url: https://nginx.org/keys/nginx_signing.key

nginx-unit-curl:
  pkg.installed:
    - pkgs: [curl]
