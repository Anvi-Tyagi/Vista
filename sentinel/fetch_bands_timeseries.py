import os, sys, datetime
from sentinelhub import SHConfig, BBox, CRS, SentinelHubRequest, MimeType, DataCollection

# ---------------- REGION INPUT ----------------
if len(sys.argv) < 6:
    print("❌ Usage:")
    print("   python3 fetch_bands_timeseries.py <regionName> <minLon> <minLat> <maxLon> <maxLat>")
    print("Example:")
    print("   python3 fetch_bands_timeseries.py Rabupura 77.55 28.20 77.65 28.30")
    sys.exit(1)

region = sys.argv[1]
min_lon, min_lat, max_lon, max_lat = map(float, sys.argv[2:6])
print(f"📡 Fetching 1-year Sentinel-2 time-series for {region}")

# ---------------- CONFIG ----------------
config = SHConfig()
if not config.sh_client_id or not config.sh_client_secret:
    raise RuntimeError("❌ Missing SH_CLIENT_ID / SH_CLIENT_SECRET in environment")

# ---------------- PATHS ----------------
BASE_DIR = os.path.expanduser("~/Desktop/VistaProject")
RAW_DIR = os.path.join(BASE_DIR, "raw_data", region)
os.makedirs(RAW_DIR, exist_ok=True)

# ---------------- BBOX ----------------
bbox = BBox([min_lon, min_lat, max_lon, max_lat], crs=CRS.WGS84)

# ---------------- TIME RANGE ----------------
today = datetime.date.today()
start_date = today - datetime.timedelta(days=365)

# ---------------- Bands ----------------
bands = ["B01", "B02", "B03", "B04", "B08", "B11", "B12"]

# ---------------- Loop over 15-day intervals ----------------
interval = 15
date_ranges = []
current = start_date
while current < today:
    end = current + datetime.timedelta(days=interval)
    if end > today:
        end = today
    date_ranges.append((current, end))
    current = end

print(f"🗓️ Total intervals: {len(date_ranges)}")

# ---------------- Fetch Each Interval ----------------
for start, end in date_ranges:
    date_str = str(start)
    date_folder = os.path.join(RAW_DIR, date_str)
    os.makedirs(date_folder, exist_ok=True)
    print(f"\n⏳ Interval: {start} → {end}")

    for band in bands:
        evalscript = f"""
        //VERSION=3
        function setup() {{
          return {{
            input: ["{band}"],
            output: {{ bands: 1, sampleType: "FLOAT32" }}
          }};
        }}
        function evaluatePixel(sample) {{
          return [sample.{band}];
        }}
        """

        request = SentinelHubRequest(
            evalscript=evalscript,
            input_data=[SentinelHubRequest.input_data(
                data_collection=DataCollection.SENTINEL2_L2A,
                time_interval=(str(start), str(end)),
                mosaicking_order="leastCC"
            )],
            responses=[SentinelHubRequest.output_response("default", MimeType.TIFF)],
            bbox=bbox,
            size=(512, 512),
            data_folder=date_folder,
            config=config
        )

        try:
            data = request.get_data(save_data=True)
            if data:
                print(f"   ✅ {band} saved in {date_folder}")
            else:
                print(f"   ⚠️ No data for {band} in {start} → {end}")
        except Exception as e:
            print(f"   ❌ Error fetching {band}: {e}")





