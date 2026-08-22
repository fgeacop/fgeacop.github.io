---
layout: page
title: FGEA CoP Community
description: Organisations and affiliate chapter regions represented in the FGEA Community of Practice.
permalink: /community/
---

Our advisory committees bring together organisations from the public sector, higher education, and industry.

{% for sector in site.data.community.sectors %}
## {{ sector.name }}

{% for organisation in sector.organisations %}
- {{ organisation }}
{% endfor %}
{% endfor %}

## Affiliate chapters

The community includes affiliate chapters in:

{% for region in site.data.community.affiliate_chapters %}
- {{ region }}
{% endfor %}
