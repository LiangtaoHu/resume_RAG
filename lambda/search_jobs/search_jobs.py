import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timezone

"""
Search-only Lambda. Forwards a keyword query to Adzuna's public jobs search
endpoint and returns the result set as a preview — nothing is written to
DynamoDB here. The SPA shows the preview and the user picks which rows to
import (which calls /api/v1/jobs/add from the job_crud Lambda).

Adzuna endpoint:
    GET https://api.adzuna.com/v1/api/jobs/{country}/search/{page}
        ?app_id={app_id}
        &app_key={app_key}
        &what={url-encoded keywords}
        &results_per_page={n}
"""

ADZUNA_APP_ID = os.environ.get("ADZUNA_APP_ID", "")
ADZUNA_APP_KEY = os.environ.get("ADZUNA_APP_KEY", "")
ADZUNA_DEFAULT_COUNTRY = os.environ.get("ADZUNA_DEFAULT_COUNTRY", "us")


def cors_headers(event):
    origin = (event.get("headers", {}) or {}).get("origin", "*")
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": origin,
    }


def get_user_identity(event):
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )
    return claims.get("sub")


def parse_body(event):
    raw = event.get("body")
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def adzuna_search(keywords, max_results, country):
    base = f"https://api.adzuna.com/v1/api/jobs/{country}/search/1"
    params = urllib.parse.urlencode({
        "app_id": ADZUNA_APP_ID,
        "app_key": ADZUNA_APP_KEY,
        "what": keywords,
        "results_per_page": max_results,
    })
    url = f"{base}?{params}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def normalize_result(item):
    company = item.get("company") or {}
    location = item.get("location") or {}
    return {
        "adzuna_id": str(item.get("id", "")),
        "title": item.get("title", ""),
        "company": company.get("display_name", "") if isinstance(company, dict) else str(company),
        "location": location.get("display_name", "") if isinstance(location, dict) else str(location),
        "url": item.get("redirect_url", ""),
        "snippet": item.get("description", "")[:280],
    }


def handler(event, context):
    headers = cors_headers(event)
    user_identity = get_user_identity(event)
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": headers,
            "body": json.dumps({"error": "Unauthorized: Missing identity from authorizer"}),
        }

    if not ADZUNA_APP_ID or not ADZUNA_APP_KEY:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Adzuna credentials not configured"}),
        }

    body = parse_body(event)
    keywords = (body.get("keywords") or "").strip()
    max_results = int(body.get("max_results") or 20)
    country = (body.get("country") or ADZUNA_DEFAULT_COUNTRY).lower()

    if not keywords:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "Missing 'keywords' parameter."}),
        }
    if max_results < 1 or max_results > 50:
        max_results = 20

    try:
        data = adzuna_search(keywords, max_results, country)
    except Exception as e:
        return {
            "statusCode": 502,
            "headers": headers,
            "body": json.dumps({"error": f"Adzuna request failed: {e}"}),
        }

    raw_results = data.get("results") or []
    results = [normalize_result(r) for r in raw_results]

    return {
        "statusCode": 200,
        "headers": headers,
        "body": json.dumps({
            "query": keywords,
            "country": country,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "results": results,
        }),
    }
