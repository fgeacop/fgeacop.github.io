---
layout: page
title: FGEA CoP Community
description: Organisations and regional chapters represented in the FGEA Community of Practice.
permalink: /community/
---

Our advisory committees bring together organisations from the public sector, higher education, and industry.

{% for sector in site.data.community.sectors %}
## {{ sector.name }}

{% for organisation in sector.organisations %}
- {{ organisation }}
{% endfor %}
{% endfor %}

## Regional chapters

FGEA CoP is developing a regional chapter network to support participation
across regions.

[Explore FGEA CoP chapters]({{ '/chapters/' | relative_url }})
