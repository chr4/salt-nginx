include:
  - nginx

{% set contact_email = salt['pillar.get']('letsencrypt:contact_email', 'hostmaster@' + grains['domain']) %}
{% set acme_challenge_dir = salt['pillar.get']('letsencrypt:acme_challenge_dir', '/etc/ssl/acme/challenges') %}
{% set acme_certificate_dir = salt['pillar.get']('letsencrypt:acme_certificate_dir', '/etc/ssl/acme/certs') %}
{% set domain = salt['pillar.get']('letsencrypt:domain', grains['fqdn']) %}
{% set altnames = salt['pillar.get']('letsencrypt:altnames', '') %}
{% set ca = salt['pillar.get']('letsencrypt:ca', none) %}
{% set ip_version = salt['pillar.get']('letsencrypt:ip_version', none) %}
{% set key_algo = salt['pillar.get']('letsencrypt:key_algo', 'rsa') %}
{% set keysize = salt['pillar.get']('letsencrypt:keysize', 4096) %}

{% for dir in [acme_challenge_dir, acme_certificate_dir, "{}/{}".format(acme_certificate_dir, domain)] %}
{{ dir }}:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: true
{% endfor %}

# Generate custom DH parameters, unless file is present
nginx-generate-dhparam:
  cmd.run:
    - name: openssl dhparam -out dhparam.pem 2048
    - cwd: {{ acme_certificate_dir }}
    - creates: {{ acme_certificate_dir }}/dhparam.pem
    - require:
      - file: {{ acme_certificate_dir }}
    - require_in:
      - validate-nginx-config

# Generate a self-signed dummy certificate, so nginx can start up
generate-dummy-cert:
  cmd.run:
    - names:
      - openssl req -x509 -nodes -batch -newkey rsa:2048 -keyout {{ acme_certificate_dir }}/{{ domain }}/dummy.key -out {{ acme_certificate_dir }}/{{ domain }}/dummy.crt -days 1 # noqa: 204
      - ln -s {{ acme_certificate_dir }}/{{ domain }}/dummy.key {{ acme_certificate_dir }}/{{ domain }}/privkey.pem
      - ln -s {{ acme_certificate_dir }}/{{ domain }}/dummy.crt {{ acme_certificate_dir }}/{{ domain }}/fullchain.pem
    - creates: {{ acme_certificate_dir }}/{{ domain }}/fullchain.pem
    - require:
      - file: {{ acme_certificate_dir }}/{{ domain }}
    - require_in:
      - validate-nginx-config


# Deploy site to answer ACME challenges
/etc/nginx/conf.d/letsencrypt.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://{{ tpldir }}/letsencrypt.nginx.jinja
    - template: jinja
    - defaults:
        fqdn: {{ domain }} {{ altnames }}
        acme_challenge_dir: {{ acme_challenge_dir }}
    - require:
      - file: /etc/nginx/conf.d

# Deploy default server
/etc/nginx/conf.d/default_server.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://{{ tpldir }}/default_server.nginx.jinja
    - template: jinja
    - defaults:
        fqdn: {{ domain }}
        acme_certificate_dir: {{ acme_certificate_dir }}
    - require:
      - file: /etc/nginx/conf.d

# Install dehydrated, bash only ACME client
dehydrated:
  pkg.installed: []
  file.managed:
    - name: /etc/dehydrated/config
    - user: root
    - group: root
    - mode: 644
    - source: salt://{{ tpldir }}/dehydrated.conf.jinja
    - template: jinja
    - defaults:
        acme_certificate_dir: {{ acme_certificate_dir }}
        acme_challenge_dir: {{ acme_challenge_dir }}
        contact_email: {{ contact_email }}
        hook: /etc/dehydrated/hook.sh
        key_algo: {{ key_algo }}
        keysize: {{ keysize }}
        {% if ca is not none %}
        ca: {{ ca }}
        {% endif %}
        {% if ip_version is not none %}
        ip_version: {{ ip_version }}
        {% endif %}
  cmd.run:
    - name: /usr/bin/dehydrated --register --accept-terms
    - onchanges:
      - pkg: dehydrated


/etc/dehydrated/domains.txt:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - contents:
      - {{ domain }} {{ salt['pillar.get']('letsencrypt:altnames', '') }}
    - require:
      - pkg: dehydrated

# Deploy hook to run upon certificate changes
/etc/dehydrated/hook.sh:
  file.managed:
    - user: root
    - group: root
    - mode: 755
    - source: salt://{{ tpldir }}/hook.sh.jinja
    - template: jinja
    - defaults:
        services: {{ salt['pillar.get']('letsencrypt:services', ['nginx']) }}
    - require:
      - pkg: dehydrated

# Deploy systemd-timer to renew letsencrypt certificates automatically
letsencrypt.timer:
  service.running:
    - enable: true
    - watch:
      - file: /etc/systemd/system/letsencrypt.timer
    - require:
      - file: /etc/systemd/system/letsencrypt.timer
      - cmd: systemctl daemon-reload
  file.managed:
    - name: /etc/systemd/system/letsencrypt.timer
    - source: salt://{{ tpldir }}/letsencrypt.timer
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /etc/systemd/system/letsencrypt.timer

/etc/systemd/system/letsencrypt.service:
  file.managed:
    - source: salt://{{ tpldir }}/letsencrypt.service
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /etc/systemd/system/letsencrypt.service

# TODO: When hostname was changed in the same salt-run, nginx is not restarted properly, and
# also certificates might be generate for the wrong domain (e.g name instead of # name.example.com)
initial-cert-request:
  cmd.run:
    - names:
      - systemctl start letsencrypt.service && rm {{ acme_certificate_dir }}/{{ domain }}/dummy.key {{ acme_certificate_dir }}/{{ domain }}/dummy.crt
    - onlyif: test -f {{ acme_certificate_dir }}/{{ domain }}/dummy.crt
    - require:
      - file: /etc/systemd/system/letsencrypt.service
      - pkg: dehydrated
      - service: nginx
