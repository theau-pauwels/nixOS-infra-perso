#!/usr/bin/env python3
"""Scrape Diesel B7 prices from carbu.com for specific stations."""

import re
import sys
import urllib.request
from datetime import datetime

# URLs for the 3 targeted locations
STATIONS = [
    (
        "Mons (7000)",
        "https://carbu.com/belgique/liste-stations-service/GO/Mons/7000/BE_ht_1945",
    ),
    (
        "Thulin (7350)",
        "https://carbu.com/belgique/liste-stations-service/GO/Thulin/7350/BE_ht_2075",
    ),
    (
        "Honnelles (7387)",
        "https://carbu.com/belgique/liste-stations-service/GO/Honnelles/7387/BE_ht_2089",
    ),
]

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "fr,en;q=0.9",
}


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8", errors="replace")


def extract_prices(html: str) -> list[str]:
    """Extract Diesel B7 prices from HTML.
    Returns list of price strings like '1,992'."""
    # Pattern: <span id="price_NNN" ...>X,XXX &euro;/L</span>
    # preceded by "Diesel (B7)" somewhere nearby
    prices = []
    for m in re.finditer(r"Diesel\s*\(B7\)", html):
        # Look forward up to 200 chars for price span
        after = html[m.end() : m.end() + 200]
        price_match = re.search(r"price_\d+\"[^>]*>([\d,]+)\s*&euro;", after)
        if price_match:
            prices.append(price_match.group(1))
    return prices


def main() -> int:
    print(f"⛽ **Prix Diesel B7 — {datetime.now().strftime('%d/%m/%Y')}**")
    print()

    for location, url in STATIONS:
        try:
            html = fetch(url)
            prices = extract_prices(html)
            if prices:
                # Convert to float for sorting
                float_prices = []
                for p in prices:
                    try:
                        float_prices.append(float(p.replace(",", ".")))
                    except ValueError:
                        float_prices.append(999.0)

                if float_prices:
                    cheapest = min(float_prices)
                    avg = sum(float_prices) / len(float_prices)
                    print(f"**{location}** — {len(prices)} prix trouves")
                    print(f"  🟢 Minimum: **{cheapest:.3f} €/L**")
                    print(f"  📊 Moyenne: {avg:.3f} €/L")
                    if len(float_prices) > 1:
                        highest = max(float_prices)
                        print(f"  🔴 Maximum: {highest:.3f} €/L")
                    print()
                else:
                    print(f"**{location}** — ⚠️ prix non parsables")
                    print()
            else:
                print(f"**{location}** — ⚠️ aucune station trouvee")
                print()
        except Exception as e:
            print(f"**{location}** — ❌ erreur: {e}", file=sys.stderr)
            print()

    print("📡 *Source: carbu.com — prix en temps reel*")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
