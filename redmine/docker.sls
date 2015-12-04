{% import_yaml "redmine/defaults.yaml" as defaults  %}
{% from "redmine/map.jinja" import get_environment with context %}

{% for docker_name in salt['pillar.get']('redmine:dockers', {}) %}
{% set docker = salt['pillar.get']('redmine:dockers:' ~ docker_name,
                                  default=defaults.docker, merge=True) %}
{% do docker.environment.extend([{'REDMINE_PORT': docker.port},
                                 {'DB_TYPE': docker.database.type},
                                 {'DB_NAME': docker.database.name},
                                 {'DB_USER': docker.database.user},
                                 {'DB_PASS': docker.database.password}]) %}
{% set links = [] %}
{% do links.append(docker.database.link ~ ':postgresql') if 'link' in docker.database %}

redmine-docker-running_{{ docker_name }}:
  dockerng.running:
    - name: {{ docker_name }}
    - image: {{ docker.image }}
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
    - binds: {{ docker.data_dir }}:{{ docker.docker_data_dir}}

{% endfor %}
