{% import_yaml "redmine/defaults.yaml" as defaults  %}
{% from "redmine/map.jinja" import get_environment with context %}

{% set images = [] %}

{% for docker_name in salt['pillar.get']('redmine:dockers', {}) %}
{% set docker = salt['pillar.get']('redmine:dockers:' ~ docker_name,
                                  default=defaults.docker, merge=True) %}
{% set links = [] %}
{% do links.append(docker.database.link ~ ':postgresql') if 'link' in docker.database %}
{% set image = docker.image if ':' in docker.image else docker.image ~ ':latest' %}
{% do images.append(image) if image not in images %}

redmine-docker-running_{{ docker_name }}:
  dockerng.running:
    - name: {{ docker_name }}
    - image: {{ image }}
    - ports:
      - {{ docker.docker_http_port }}
      - {{ docker.docker_https_port }}
    - links:
      {% for link in links %}
      - {{ link }}
      {% endfor %}
    - environment:
      {{ get_environment(docker)|indent(6)}}
    {% if 'publish' in docker %}
    {%   if docker.https %}
    - port_bindings: {{ docker.publish }}:{{ docker.docker_https_port }}
    {%   else %}
    - port_bindings: {{ docker.publish }}:{{ docker.docker_http_port }}
    {%   endif %}
    {% endif %}
    - binds:
      - {{ docker.data_dir }}:{{ docker.docker_data_dir}}
      {% for bind in docker.get('binds', []) %}
      - {{ bind }}
      {% endfor %}
    - require:
      - cmd: redmine-docker-image_{{ image }}

{% if 'certs' in docker %}
  {% set certs = { 'redmine.key':docker.certs.key, 'redmine.crt':docker.certs.crt} %}
  {% do certs.update({'dhparam.pem':docker.certs.dhparam }) if 'dhparam' in docker.certs %}
  {% for cert_name, cert in certs.items() %}
redmine-docker-{{ docker_name}}-certs_{{ cert_name }}:
  file.copy:
    - name: {{ cert.get('path', docker.data_dir ~ '/certs/' ~  cert_name) }}
    - source: {{ cert.source }}
    - makedirs: True
    - force: True
    - mode: 400   # read only
    - watch_in:
      - dockerng: {{ docker_name }}

  {% endfor %}
{% endif %}

{% if 'themes' in docker %}
{{ docker.data_dir }}/themes:
  file.directory:
    - makedirs: True
{% endif %}

{% for theme_name, theme in docker.get('themes', {}).items() %}
{% if 'archive' in theme %}
redmine-docker_{{ docker_name }}_theme_{{ theme_name }}:
  archive.extracted:
    - name: {{ docker.data_dir }}/themes/{{ theme_name }}
    - source: {{ theme.archive.source }}
    - source_hash: {{ theme.archive.hash }}
    - archive_format: {{ theme.archive.format }}
    {% if 'strip' in theme.archive %}
    - tar_options: --strip={{ theme.archive.strip }}
    {% endif %}
    - require:
      - file: {{ docker.data_dir }}/themes
    - watch_in:
      - dockerng: {{ docker_name }}
    - if_missing: {{ docker.data_dir }}/themes/{{ theme_name }}/stylesheets/application.css
{% endif %}
{% endfor %}

{% endfor %}

{% for image in images %}
redmine-docker-image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }}) ]'
{% endfor %}
