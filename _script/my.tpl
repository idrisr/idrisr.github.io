{% extends "index.md.j2" %}
{%- block header -%}
---
{% for key, value in resources['front_matter'].items() -%}
  {{key}}: {{value}}
{% endfor -%}
---
{{ super() }}
{%- endblock header -%}

{% block data_png %}
    {% if "filenames" in output.metadata %}
{{ output.metadata.filenames['image/png'] | jekyllify }}
    {% else %}
![png](data:image/png;base64,{{ output.data['image/png'] }})
    {% endif %}
{% endblock data_png %}
