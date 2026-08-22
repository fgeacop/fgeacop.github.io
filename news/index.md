---
layout: page
title: FGEA CoP News
description: Announcements and records from the Future Generation Enterprise Architecture Community of Practice.
permalink: /news/
---

FGEA Community of Practice announcements, event records, and updates.

{% assign published_posts = site.posts | where: "published", true | sort: "date" | reverse %}
{% for post in published_posts %}
## [{{ post.title }}]({{ post.url | relative_url }})

<time datetime="{{ post.date | date: '%Y-%m-%d' }}">{{ post.date | date: "%-d %B %Y" }}</time> · {{ post.kind | capitalize }}

{{ post.summary }}
{% endfor %}
