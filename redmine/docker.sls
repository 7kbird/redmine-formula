{% import_yaml "redmine/defaults.yaml" as defaults  %}
{% from "redmine/map.jinja" import get_environment with context %}

{% set images = [] %}

{% for docker_name in salt['pillar.get']('redmine:dockers', {}) %}
{% set docker = salt['pillar.get']('redmine:dockers:' ~ docker_name,
                                  default=defaults.docker, merge=True) %}
{% set links = [] %}
{% do links.append(docker.database.link ~ ':postgresql') if 'link' in docker.database %}
{% set image = docker.image if ':' in docker.image else docker.image ~ ':latest'%}
{% do images.append(image) if image not in images%}

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
    - binds: {{ docker.data_dir }}:{{ docker.docker_data_dir}}
    - require:
      - cmd: redmine-docker-image_{{ image }}

{% endfor %}

{% for image in images %}
redmine-docker-image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }} ]'
{% endfor %}
