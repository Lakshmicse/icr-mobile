"""Re-captures the Marketplace tests' fixtures from the LOCAL portal API.

    python tool/seed/marketplace_fixtures.py

Run it after tool/seed/marketplace.ts when the seed changes: the unit tests
(test/marketplace_test.dart) read what the portal answers for the seeded
suppliers, so a parser that drifts from the real API fails there.
Needs the API at http://localhost:3001/api/v1 and the demo persona Bharat Buyer.
"""
import json
import os
import urllib.request

BASE = "http://localhost:3001/api/v1"
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "marketplace")


def login(email, password):
    req = urllib.request.Request(
        BASE + "/auth/login",
        data=json.dumps({"email": email, "password": password, "rememberMe": False}).encode(),
        headers={"Content-Type": "application/json"},
    )
    return json.load(urllib.request.urlopen(req))["accessToken"]


def get(path, token=None):
    headers = {"Authorization": "Bearer " + token} if token else {}
    return json.load(urllib.request.urlopen(urllib.request.Request(BASE + path, headers=headers)))


def save(name, obj):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w", encoding="utf8") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)


def trim(node, depth=0):
    node = dict(node)
    node["children"] = [trim(c, depth + 1) for c in node.get("children", [])[:3]] if depth < 2 else []
    return node


token = login("buyer@icr.dev", "Buyer@123")
save("vendors_page.json", get("/vendors?limit=3&minVerificationLevel=VERIFIED&sortBy=rating&sortDir=desc"))
save("vendor_detail.json", get("/vendors/design-mkt-v-vikasha?countView=false"))
save("vendor_detail_card.json", get("/vendors/design-mkt-v-bluedot?countView=false"))
save("services_page.json", get("/services?companyId=design-mkt-co-vikasha&limit=50"))
save("products_page.json", get("/products?companyId=design-mkt-co-securetech&limit=50"))
save("certifications_verified.json", get("/certifications/verified?companyId=design-mkt-co-vikasha"))
save("certification_types.json", [t for t in get("/certifications/types") if t["slug"].startswith("design-mkt-")])
save("categories_tree.json", [trim(n) for n in get("/categories/tree?depth=3") if n["key"] in ("SECURITY", "FACILITY_MANAGEMENT")])
save("category_counts.json", get("/vendors/category-counts"))
save("cities.json", get("/vendors/cities"))
save("rfq_summary.json", get("/rfq/mine/summary", token))
save("unread_count.json", get("/notifications/unread-count", token))
save("saved_ids.json", get("/vendors/saved/ids", token))
print("fixtures written to", os.path.abspath(OUT))
