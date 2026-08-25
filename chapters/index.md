---
layout: page
title: FGEA CoP Chapters
description: Regional FGEA Community of Practice chapters and the shared quarterly symposium hosting model.
permalink: /chapters/
---

FGEA CoP is developing a network of regional chapters with local home bases
and a shared global programme. Chapters create regional points of connection
while contributing to one community and one quarterly symposium series.

{% for chapter in site.data.community.chapters %}
<h2 id="{{ chapter.slug }}">{{ chapter.name }}</h2>

**{{ chapter.status_label }}**

**Home base:** {{ chapter.home_base }}

{{ chapter.description }}
{% endfor %}

## Shared symposium programme

**Format:** {{ site.data.community.symposium_hosting.format }}

{{ site.data.community.symposium_hosting.description }}

Hosting details will be identified on each event page as the programme develops.
Browse [upcoming and previous symposiums]({{ '/events/' | relative_url }}) for
the latest published information.

## Participate or present

Use the FGEA CoP registration form to register your interest in participating
in the community and its symposiums.

<p><a class="button button-primary" href="{{ site.data.organization.registration_url }}" rel="noopener">Register with FGEA CoP <span aria-hidden="true">↗</span></a></p>

To propose a presentation, case study, or talk for a future symposium, email
[{{ site.data.organization.email }}](mailto:{{ site.data.organization.email }}?subject={{ site.data.organization.speaker_subject | uri_escape }}).
