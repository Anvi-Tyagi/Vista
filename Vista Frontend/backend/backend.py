from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
from datetime import datetime, timedelta, timezone
import os

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)

# ---------------------------
# CONFIG: Add your credentials
# ---------------------------
CLIENT_ID = "sh-c0443886-0a34-4441-8aa9-e7daa35703d3"
CLIENT_SECRET = "DWEhZK4aRhRDw4aMWNNX8TSQWC3U3zhF"

TOKEN_URL = "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"
PROCESS_URL = "https://sh.dataspace.copernicus.eu/api/v1/process"

# ---------------------------
# Helper: Get fresh token
# ---------------------------
def get_token():
    data = {
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET
    }
    r = requests.post(TOKEN_URL, data=data)
    if r.status_code != 200:
        print("❌ Failed to get token:", r.status_code, r.text)
        raise Exception("Token fetch failed")
    return r.json()["access_token"]

# ---------------------------
# Helper: Fetch from Copernicus with fallback
# ---------------------------
def fetch_from_copernicus(bbox, evalscript, filename):
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=90)  # last 90 days

    token = get_token()
    headers = {"Authorization": f"Bearer {token}"}

    for dataset in ["sentinel-2-l2a", "sentinel-2-l1c"]:
        print(f"🔎 Trying dataset: {dataset}")
        body = {
            "input": {
                "bounds": {"bbox": bbox},
                "data": [{
                    "type": dataset,
                    "dataFilter": {
                        "timeRange": {
                            "from": start_date.strftime("%Y-%m-%dT%H:%M:%SZ"),
                            "to":   end_date.strftime("%Y-%m-%dT%H:%M:%SZ")
                        },
                        "maxCloudCoverage": 100
                    }
                }]
            },
            "output": {
                "responses": [{
                    "identifier": "default",
                    "format": {"type": "image/tiff"}
                }]
            },
            "evalscript": evalscript
        }

        r = requests.post(PROCESS_URL, json=body, headers=headers)

        if r.status_code == 200 and "tiff" in r.headers.get("Content-Type", "") and len(r.content) > 5000:
            # Always save inside backend/ folder
            filepath = os.path.join("backend", filename)
            with open(filepath, "wb") as f:
                f.write(r.content)
            print(f"✅ Saved TIFF: {filepath} | Size: {len(r.content)} bytes | Dataset: {dataset}")
            return {"filename": filepath, "dataset": dataset}

        print(f"⚠️ No data or tiny TIFF from {dataset}, trying next...")

    return {"error": "No valid data found in last 90 days."}

# ---------------------------
# API Routes
# ---------------------------
@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"message": "✅ Backend is alive"}), 200

@app.route("/fetch-rgb", methods=["POST", "OPTIONS"])
def fetch_rgb():
    if request.method == "OPTIONS":
        return jsonify({"message": "CORS preflight OK"}), 200

    bbox = [float(x) for x in request.json["bbox"].split(",")]
    print("📌 Received AOI BBOX (RGB):", bbox)

    evalscript = """
    //VERSION=3
    function setup() {
      return {
        input: ["B04","B03","B02"],
        output: { bands: 3 }
      };
    }
    function evaluatePixel(s) {
      return [s.B04/10000, s.B03/10000, s.B02/10000];
    }
    """
    return jsonify(fetch_from_copernicus(bbox, evalscript, "output_rgb.tiff"))

@app.route("/fetch-bands", methods=["POST", "OPTIONS"])
def fetch_bands():
    if request.method == "OPTIONS":
        return jsonify({"message": "CORS preflight OK"}), 200

    bbox = [float(x) for x in request.json["bbox"].split(",")]
    print("📌 Received AOI BBOX (Bands):", bbox)

    evalscript = """
    //VERSION=3
    function setup() {
      return {
        input: ["B04","B05","B06","B07","B08","B11","B12"],
        output: { bands: 8 }
      };
    }
    function evaluatePixel(s) {
      let ndvi = (s.B08 - s.B04) / (s.B08 + s.B04 + 0.00001);
      return [
        ndvi,        // 1: NDVI
        s.B04/10000, // 2: Red
        s.B08/10000, // 3: NIR
        s.B05/10000, // 4: Red Edge 1
        s.B06/10000, // 5: Red Edge 2
        s.B07/10000, // 6: Red Edge 3
        s.B12/10000, // 7: SWIR 2
        s.B11/10000  // 8: SWIR 1
      ];
    }
    """
    return jsonify(fetch_from_copernicus(bbox, evalscript, "output_bands.tiff"))

# ---------------------------
# Run server
# ---------------------------
if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050, debug=True, use_reloader=False)
