include:
  - nginx.unit.repository

unit-php:
  pkg.installed: []
  service.running:
    - name: unit
    - enable: true
    - watch:
      - pkg: unit-php
