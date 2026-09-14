from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import os
import csv

app = Flask(__name__)
CORS(app)

# 🔹 Health check endpoint
@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"}), 200


# 🔹 Run pipeline
@app.route("/run_pipeline", methods=["POST"])
def run_pipeline():
    data = request.get_json()
    region = data.get("region")
    bbox = data.get("bbox")  # [minLon, minLat, maxLon, maxLat]

    if not region or not bbox:
        return jsonify({"status": "error", "error": "Missing region or bbox"}), 400

    try:
        # 1️⃣ Run fetch_bands.py
        fetch_cmd = [
            "python3",
            "/Users/adityamehrotra/Desktop/VistaProject/sentinel/fetch_bands.py",
            region, str(bbox[0]), str(bbox[1]), str(bbox[2]), str(bbox[3])
        ]
        fetch_result = subprocess.run(fetch_cmd, capture_output=True, text=True)

        # 2️⃣ Run MATLAB pipeline (make sure path is set!)
        matlab_cmd = [
            "matlab", "-batch",
            f"addpath('/Users/adityamehrotra/Desktop/VistaProject/matlab_scripts'); run_pipeline('{region}')"
        ]
        matlab_result = subprocess.run(matlab_cmd, capture_output=True, text=True)

        # 3️⃣ Locate processed results
        base = f"/Users/adityamehrotra/Desktop/VistaProject/processed_data/{region}"
        ndvi_file = os.path.join(base, "ndvi.tif")
        pest_file = os.path.join(base, "pest_map.png")
        crop_file = os.path.join(base, "crop_health.csv")

        # 4️⃣ Extract values
        ndvi_value = None
        crop_health_value = None
        pest_risk_value = None

        if "NDVI=" in matlab_result.stdout:
            try:
                ndvi_value = float(matlab_result.stdout.split("NDVI=")[-1].split()[0])
            except:
                pass

        if os.path.exists(crop_file):
            with open(crop_file, newline="") as f:
                reader = csv.reader(f)
                header = next(reader, None)
                row = next(reader, None)
                if row:
                    crop_health_value = row[-1]

        if "PestRisk" in matlab_result.stdout:
            pest_risk_value = matlab_result.stdout.split("PestRisk")[-1].split()[0].strip()

        # 5️⃣ Build response
        return jsonify({
            "status": "success",
            "region": region,
            "ndvi": ndvi_value,
            "pest": pest_risk_value,
            "crop_health": crop_health_value,
            "stdout": matlab_result.stdout,
            "stderr": matlab_result.stderr,
            "files": {
                "ndvi": ndvi_file if os.path.exists(ndvi_file) else None,
                "pest_map": pest_file if os.path.exists(pest_file) else None,
                "crop_health": crop_file if os.path.exists(crop_file) else None
            }
        })

    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500


if __name__ == "__main__":
    # Use port 5001 (5000 is blocked by AirPlay on macOS)
    app.run(host="0.0.0.0", port=5001, debug=True)
