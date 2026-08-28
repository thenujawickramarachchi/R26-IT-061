from __future__ import annotations

import argparse
import json
import urllib.request


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8000/v1/analyze")
    parser.add_argument("--api-key", default="")
    args = parser.parse_args()

    payload = {
        "text": "අවශ්‍ය නැහැ",
        "previous_context": None,
        "language": "Sinhala",
        "operation": "auto",
    }
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        args.url,
        data=body,
        headers={
            "Content-Type": "application/json; charset=utf-8",
            **({"X-API-Key": args.api_key} if args.api_key else {}),
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        print(json.dumps(json.load(response), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
