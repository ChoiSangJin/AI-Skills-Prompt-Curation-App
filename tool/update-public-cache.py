#!/usr/bin/env python3
import argparse
import json
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

CATEGORIES = {
    'Skills': (['agent-skills', 'claude-skills', 'claude-code-skills'], 30, 3),
    'MCP / Agent': (['mcp-server', 'model-context-protocol'], 50, 10),
    'Coding Rules': (['cursor-rules', 'claude-code', 'coding-agent'], 30, 5),
    'Prompts': (['prompt-engineering', 'awesome-prompts', 'midjourney-prompts'], 100, 10),
}
PAGE_SIZE = 20


def merge_topics(per_topic):
    picked = {}
    quota = PAGE_SIZE // len(per_topic)
    for items in per_topic:
        for item in sorted(items, key=lambda value: value['stargazers_count'], reverse=True)[:quota]:
            picked.setdefault(item['full_name'], item)
    remaining = sorted(
        (item for items in per_topic for item in items),
        key=lambda value: value['stargazers_count'], reverse=True)
    for item in remaining:
        if len(picked) >= PAGE_SIZE:
            break
        picked.setdefault(item['full_name'], item)
    return sorted(picked.values(), key=lambda value: value['stargazers_count'], reverse=True)


def search(topic, feed, minimum, token, since):
    query = f'topic:{topic} stars:>{minimum}'
    if feed == 'rising':
        query = f'topic:{topic} created:>{since} stars:>{minimum}'
    url = 'https://api.github.com/search/repositories?' + urllib.parse.urlencode({
        'q': query, 'sort': 'stars', 'order': 'desc', 'per_page': PAGE_SIZE,
    })
    request = urllib.request.Request(url, headers={
        'Accept': 'application/vnd.github+json',
        'Authorization': f'Bearer {token}',
        'User-Agent': 'AI-Moa-Public-Cache',
        'X-GitHub-Api-Version': '2022-11-28',
    })
    with urllib.request.urlopen(request, timeout=30) as response:
        items = json.load(response)['items']
    fields = ('full_name', 'html_url', 'stargazers_count', 'description',
              'language', 'topics', 'pushed_at')
    return [{field: item.get(field) for field in fields} for item in items]


def build_cache(token, pause=2.1):
    now = datetime.now(timezone.utc)
    since = (now - timedelta(days=30)).date().isoformat()
    feeds = {}
    for feed in ('popular', 'rising'):
        categories = {}
        for name, (topics, popular_minimum, rising_minimum) in CATEGORIES.items():
            minimum = popular_minimum if feed == 'popular' else rising_minimum
            per_topic = []
            for topic in topics:
                per_topic.append(search(topic, feed, minimum, token, since))
                if pause:
                    time.sleep(pause)
            categories[name] = merge_topics(per_topic)
        feeds[feed] = categories
    return {'version': 1, 'generated_at': now.isoformat(), 'feeds': feeds}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output')
    args = parser.parse_args()
    token = os.environ.get('GH_TOKEN', '')
    if not token:
        raise SystemExit('GH_TOKEN is required')
    with open(args.output, 'w', encoding='utf-8') as handle:
        json.dump(build_cache(token), handle, ensure_ascii=False,
                  separators=(',', ':'))


if __name__ == '__main__':
    main()
