---
layout: page
title: FGEA CoP Resources
description: Verified resources shared by the Future Generation Enterprise Architecture Community of Practice.
permalink: /resources/
---

{% assign published_resources = site.resources | where: "published", true | sort: "published_date" | reverse %}
{% if published_resources.size > 0 %}
<div class="card-grid">
{% for resource in published_resources %}
{% include resource-card.html resource=resource %}
{% endfor %}
</div>
{% else %}
No resources have been published yet. Reviewed FGEA CoP resources will be listed here when they become available.

For current announcements and event information, visit [News]({{ '/news/' | relative_url }}) or [Events]({{ '/events/' | relative_url }}).
{% endif %}
