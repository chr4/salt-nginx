include:
  - iptables

{% for v in [4, 6] %}
# Insert iptables rule right after initial rules (pos 5)
nginx_iptables_ipv{{v}}:
  iptables.insert:
    - position: 5
    - family: ipv{{v}}
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - match: state
    - connstate: NEW
    - dports: [80, 443]
    - proto: tcp
    - sport: 1025:65535
    - save: true
{% endfor %}
