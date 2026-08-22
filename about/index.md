---
layout: page
title: About FGEA CoP
description: The purpose, principles, and leadership of the Future Generation Enterprise Architecture Community of Practice.
permalink: /about/
---

## {{ site.data.organization.purpose.heading }}

{{ site.data.organization.purpose.lead }}

{{ site.data.organization.purpose.detail }}

## Our principles

{% for principle in site.data.organization.principles %}
### {{ principle.name }}

{{ principle.description }}
{% endfor %}

## Leadership

{% for person in site.data.people.leadership %}
### {{ person.name }}

{{ person.role }}<br>
{{ person.affiliation }}
{% endfor %}

## Advisory panel

{% for person in site.data.people.advisory_panel %}
- **{{ person.name }}**, {{ person.affiliation }}
{% endfor %}

## Advisory committee chairs

{% for person in site.data.people.advisory_committee_chairs %}
- **{{ person.name }}**, {{ person.sector }}, {{ person.affiliation }}
{% endfor %}

The community purpose and structure are preserved from the
[DigiSAS Lab FGEA CoP overview](https://www.digisaslab.org/fgea-cop/).
