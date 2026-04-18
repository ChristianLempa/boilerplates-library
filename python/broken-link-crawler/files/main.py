#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from collections import deque
from typing import Any
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup
from requests import Response
from requests.exceptions import RequestException


WEBSITE_URL = r"""<< website_url >>"""
MAX_PAGES_DEFAULT = int(r"""<< max_pages >>""")
REQUEST_TIMEOUT_SECONDS_DEFAULT = int(r"""<< request_timeout_seconds >>""")
VERIFY_TLS_DEFAULT = r"""<< verify_tls >>"""
FOLLOW_REDIRECTS_DEFAULT = r"""<< follow_redirects >>"""
REQUEST_HEADERS_JSON_DEFAULT = r"""<< request_headers_json >>"""
USER_AGENT_DEFAULT = r"""<< user_agent >>"""


def str_to_bool(value: Any) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def parse_json_object(value: str, field_name: str) -> dict[str, Any]:
    if not value.strip():
        return {}
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{field_name} must be valid JSON: {exc}") from exc
    if not isinstance(parsed, dict):
        raise SystemExit(f"{field_name} must be a JSON object.")
    return parsed


def build_session(headers: dict[str, str], user_agent: str) -> requests.Session:
    session = requests.Session()
    session.headers.update({"User-Agent": user_agent})
    session.headers.update(headers)
    return session


def sanitize_url(url: str) -> str | None:
    parsed = urlparse(url)
    if parsed.scheme in {"mailto", "javascript", "tel", "data"}:
        return None
    cleaned = parsed._replace(fragment="").geturl()
    return cleaned or None


def same_host(url: str, website_host: str) -> bool:
    host = (urlparse(url).hostname or "").lower()
    return bool(host) and host == website_host


def is_html_response(response: Response) -> bool:
    content_type = response.headers.get("Content-Type", "").lower()
    return "text/html" in content_type or "application/xhtml+xml" in content_type


def probe_url(
    session: requests.Session,
    url: str,
    timeout: int,
    verify_tls: bool,
    follow_redirects: bool,
) -> tuple[Response | None, str | None]:
    try:
        response = session.get(
            url,
            timeout=timeout,
            verify=verify_tls,
            allow_redirects=follow_redirects,
        )
        return response, None
    except RequestException as exc:
        return None, str(exc)


def main() -> int:
    website_url = WEBSITE_URL.strip()
    if not website_url:
        raise SystemExit("website_url is required.")
    website_host = (urlparse(website_url).hostname or "").lower()
    if not website_host:
        raise SystemExit("website_url must include a valid hostname.")

    verify_tls = str_to_bool(VERIFY_TLS_DEFAULT)
    follow_redirects = str_to_bool(FOLLOW_REDIRECTS_DEFAULT)

    request_headers = parse_json_object(REQUEST_HEADERS_JSON_DEFAULT, "request_headers_json")
    session = build_session(request_headers, USER_AGENT_DEFAULT.strip())

    queue: deque[tuple[str, str]] = deque([(website_url, website_url)])
    queued_urls = {website_url}
    visited_pages: set[str] = set()
    checked_resources: dict[str, dict[str, Any]] = {}
    broken: dict[str, dict[str, Any]] = {}

    pages_crawled = 0

    while queue and pages_crawled < MAX_PAGES_DEFAULT:
        page_url, source = queue.popleft()
        if page_url in visited_pages:
            continue
        visited_pages.add(page_url)

        response, error = probe_url(
            session=session,
            url=page_url,
            timeout=REQUEST_TIMEOUT_SECONDS_DEFAULT,
            verify_tls=verify_tls,
            follow_redirects=follow_redirects,
        )
        pages_crawled += 1

        if error:
            broken.setdefault(
                page_url,
                {"url": page_url, "kind": "page", "status_code": None, "error": error, "sources": []},
            )["sources"].append(source)
            continue

        if response is None:
            continue

        if response.status_code >= 400:
            broken.setdefault(
                page_url,
                {
                    "url": page_url,
                    "kind": "page",
                    "status_code": response.status_code,
                    "error": f"HTTP {response.status_code}",
                    "sources": [],
                },
            )["sources"].append(source)
            continue

        if not is_html_response(response):
            continue

        soup = BeautifulSoup(response.text, "html.parser")

        discovered: list[tuple[str, str]] = []
        for tag_name, attribute, kind in [
            ("a", "href", "link"),
            ("img", "src", "asset"),
            ("script", "src", "asset"),
            ("link", "href", "asset"),
        ]:
            for tag in soup.find_all(tag_name):
                raw_value = tag.get(attribute)
                if not raw_value:
                    continue
                normalized = sanitize_url(urljoin(page_url, raw_value))
                if not normalized:
                    continue
                discovered.append((normalized, kind))

        for discovered_url, kind in discovered:
            if not same_host(discovered_url, website_host):
                continue

            if kind == "link" and discovered_url not in visited_pages and discovered_url not in queued_urls:
                queue.append((discovered_url, page_url))
                queued_urls.add(discovered_url)

            if discovered_url in checked_resources:
                checked_resources[discovered_url]["sources"].add(page_url)
                if discovered_url in broken:
                    broken[discovered_url]["sources"].append(page_url)
                continue

            resource_response, resource_error = probe_url(
                session=session,
                url=discovered_url,
                timeout=REQUEST_TIMEOUT_SECONDS_DEFAULT,
                verify_tls=verify_tls,
                follow_redirects=follow_redirects,
            )

            checked_resources[discovered_url] = {
                "url": discovered_url,
                "kind": kind,
                "sources": {page_url},
            }

            if resource_error:
                broken[discovered_url] = {
                    "url": discovered_url,
                    "kind": kind,
                    "status_code": None,
                    "error": resource_error,
                    "sources": [page_url],
                }
                continue

            if resource_response is not None and resource_response.status_code >= 400:
                broken[discovered_url] = {
                    "url": discovered_url,
                    "kind": kind,
                    "status_code": resource_response.status_code,
                    "error": f"HTTP {resource_response.status_code}",
                    "sources": [page_url],
                }

    for value in broken.values():
        value["sources"] = sorted(set(value["sources"]))

    summary = {
        "pages_crawled": pages_crawled,
        "urls_checked": len(set(checked_resources) | visited_pages),
        "broken_urls": len(broken),
    }
    overall_status = "fail" if broken else "pass"
    sorted_broken = sorted(broken.values(), key=lambda item: item["url"])

    print(f"Broken Link Crawler: {overall_status.upper()}")
    print(f"Website: {website_url}")
    print(f"Pages crawled: {pages_crawled}")
    print(f"URLs checked: {summary['urls_checked']}")
    print(f"Broken URLs: {summary['broken_urls']}")
    if sorted_broken:
        print("")
        print("Broken targets:")
        for item in sorted_broken:
            source = ", ".join(item["sources"][:3]) or "-"
            print(f"- [{item['kind']}] {item['url']} | source={source} | error={item['error']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
