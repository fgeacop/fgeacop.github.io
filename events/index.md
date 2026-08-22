---
layout: page
title: FGEA CoP Events
description: Upcoming and past symposiums from the Future Generation Enterprise Architecture Community of Practice.
permalink: /events/
---

{{ site.data.organization.symposiums.description }}

## Upcoming events

{% if site.upcoming_events.size > 0 %}
{% for event in site.upcoming_events %}
### [{{ event.title }}]({{ event.url | relative_url }})

{{ event.start_date | date: "%-d %B %Y" }} · {{ event.format | replace: "-", " " | capitalize }} · {{ event.event_status | capitalize }}

{{ event.summary }}
{% endfor %}
{% else %}
No upcoming events have been published. [Contact FGEA CoP]({{ '/contact/' | relative_url }}) to express interest in future symposiums.
{% endif %}

## Past events

{% if site.past_events.size > 0 %}
{% for event in site.past_events %}
### [{{ event.title }}]({{ event.url | relative_url }})

{{ event.start_date | date: "%-d %B %Y" }} · {{ event.format | replace: "-", " " | capitalize }}

{{ event.summary }}
{% endfor %}
{% else %}
No past events have been published.
{% endif %}
