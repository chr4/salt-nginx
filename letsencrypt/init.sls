include:
  - nginx

{% set contact_email = salt['pillar.get']('letsencrypt:contact_email', 'hostmaster@' + grains['domain']) %}
{% set acme_challenge_dir = salt['pillar.get']('letsencrypt:acme_challenge_dir', '/etc/ssl/acme/challenges') %}
{% set acme_certificate_dir = salt['pillar.get']('letsencrypt:acme_certificate_dir', '/etc/ssl/acme/certs') %}
{% set domain = salt['pillar.get']('letsencrypt:domain', grains['fqdn']) %}
{% set altnames = salt['pillar.get']('letsencrypt:altnames', '') %}

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

# Generate a self-signed dummy certificate, so nginx can start up
generate-dummy-cert:
  cmd.run:
    - names:
      - openssl req -x509 -nodes -batch -newkey rsa:2048 -keyout {{ acme_certificate_dir }}/{{ domain }}/dummy.key -out {{ acme_certificate_dir }}/{{ domain }}/dummy.crt -days 1
      - ln -s {{ acme_certificate_dir }}/{{ domain }}/dummy.key {{ acme_certificate_dir }}/{{ domain }}/privkey.pem
      - ln -s {{ acme_certificate_dir }}/{{ domain }}/dummy.crt {{ acme_certificate_dir }}/{{ domain }}/fullchain.pem
    - creates: {{ acme_certificate_dir }}/{{ domain }}/fullchain.pem
    - require:
      - file: {{ acme_certificate_dir }}/{{ domain }}


# Deploy site to answer ACME challenges
/etc/nginx/conf.d/letsencrypt.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://{{ tpldir }}/letsencrypt.nginx.jinja
    - template: jinja
    - defaults:
      acme_challenge_dir: {{ acme_challenge_dir }}
    - require:
      - file: /etc/nginx/conf.d
      - file: {{ acme_challenge_dir }}

# Install dehydrated, bash only ACME client
dehydrated:
  # Ubuntu Xenial doesn't have dehydrated available, so installing it manually
{% if grains['osrelease'] | float <= 16.04 %}
  pkg.installed:
    - sources:
      - dehydrated: http://de.archive.ubuntu.com/ubuntu/pool/universe/d/dehydrated/dehydrated_0.6.1-2_all.deb
{% else %}
  pkg.installed: []
{% endif %}
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
  cmd.run:
    - name: /usr/bin/dehydrated --register --accept-terms
    - onchanges:
      - pkg: dehydrated
    - require:
      - file: /etc/dehydrated/config


/etc/dehydrated/domains.txt:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - contents:
      - {{ domain }} {{ salt['pillar.get']('letsencrypt:altnames', '') }}
    - require:
      - dehydrated

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
      - file: /etc/dehydrated/domains.txt

# Deploy systemd-timer to renew letsencrypt certificates automatically
letsencrypt.timer:
  service.running:
    - enable: true
    - watch:
      - file: /lib/systemd/system/letsencrypt.timer
    - require:
      - file: /lib/systemd/system/letsencrypt.timer
      - cmd: systemctl daemon-reload
  file.managed:
    - name: /lib/systemd/system/letsencrypt.timer
    - source: salt://{{ tpldir }}/letsencrypt.timer
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /lib/systemd/system/letsencrypt.timer

/lib/systemd/system/letsencrypt.service:
  file.managed:
    - source: salt://{{ tpldir }}/letsencrypt.service
    - user: root
    - group: root
    - mode: 644
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: /lib/systemd/system/letsencrypt.service

# TODO: When hostname was changed in the same salt-run, nginx is not restarted properly, and
# also certificates might be generate for the wrong domain (e.g name instead of # name.example.com)
initial-cert-request:
  cmd.run:
    - names:
      - systemctl start nginx.service letsencrypt.service && rm {{ acme_certificate_dir }}/{{ domain }}/dummy.key {{ acme_certificate_dir }}/{{ domain }}/dummy.crt
    - onlyif: test -f {{ acme_certificate_dir }}/{{ domain }}/dummy.crt
    - require:
      - dehydrated
      - file: /etc/dehydrated/hook.sh
      - cmd: /lib/systemd/system/letsencrypt.service
