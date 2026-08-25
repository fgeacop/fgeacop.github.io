---
layout: page
title: FGEA CoP Chapters
description: Regional chapters of the Future Generation Enterprise Architecture Community of Practice.
permalink: /chapters/
---

FGEA CoP is developing a network of regional chapters with local home bases.
Chapters create regional points of connection within one community.

{% for chapter in site.data.community.chapters %}
<h2 id="{{ chapter.slug }}">{{ chapter.name }}</h2>

**{{ chapter.status_label }}**

**Home base:** {{ chapter.home_base }}

{{ chapter.description }}
{% endfor %}

## Participate or present

Use the FGEA CoP registration form to register your interest in participating
in the community and its symposiums.

<p><a class="button button-primary" href="{{ site.data.organization.registration_url }}" rel="noopener">Register with FGEA CoP <span aria-hidden="true">↗</span></a></p>

To propose a presentation, case study, or talk for a future symposium, email
[{{ site.data.organization.email }}](mailto:{{ site.data.organization.email }}?subject={{ site.data.organization.speaker_subject | uri_escape }}).
