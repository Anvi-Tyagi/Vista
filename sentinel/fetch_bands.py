import os, sys, datetime
import rasterio
from rasterio.transform import from_origin
from sentinelhub import SHConfig, BBox, CRS, SentinelHubRequest, MimeType, DataCollection

# ---------------- REGION INPUT ----------------
if len(sys.argv) < 6:
    print("❌ Usage:")
    print("   python3 fetch_bands.py <regionName> <minLon> <minLat> <maxLon> <maxLat>")
    print("Example:")
    print("   python3 fetch_bands.py Amritsar 74.75 31.5 75.1 31.7")
    sys.exit(1)

region = sys.argv[1]
min_lon, min_lat, max_lon, max_lat = map(float, sys.argv[2:6])
print(f"📡 Fetching Sentinel-2 bands for {region} @ BBox=({min_lon},{min_lat},{max_lon},{max_lat})")

# ---------------- CONFIG ----------------
config = SHConfig()
if not config.sh_client_id or not config.sh_client_secret:
    raise RuntimeError("❌ Missing SH_CLIENT_ID / SH_CLIENT_SECRET in environment")

# ---------------- PATHS ----------------
BASE_DIR = os.path.expanduser("~/Desktop/VistaProject")
RAW_DIR = os.path.join(BASE_DIR, "raw_data", region)
os.makedirs(RAW_DIR, exist_ok=True)

# ---------------- BBOX ----------------
district_bbox = BBox([min_lon, min_lat, max_lon, max_lat], crs=CRS.WGS84)

# ---------------- TIME WINDOW ----------------
today = datetime.date.today()
week_ago = today - datetime.timedelta(days=7)

# ---------------- BANDS ----------------
bands = ["B02", "B03", "B04", "B08", "B11", "B12"]

for band in bands:
    evalscript = f"""
    //VERSION=3
    function setup() {{
      return {{
        input: ["{band}"],
        output: {{ bands: 1, sampleType: "FLOAT32" }}
      }};
    }}
    function evaluatePixel(s) {{
      return [s.{band}];
    }}
    """

    request = SentinelHubRequest(
        evalscript=evalscript,
        input_data=[SentinelHubRequest.input_data(
            data_collection=DataCollection.SENTINEL2_L2A,
            time_interval=(str(week_ago), str(today)),
            mosaicking_order="leastCC"
        )],
        responses=[SentinelHubRequest.output_response("default", MimeType.TIFF)],
        bbox=district_bbox,
        size=(512, 512),
        config=config
    )

    # ✅ Get data (list of numpy arrays)
    data = request.get_data()

    if not data or len(data) == 0:
        print(f"⚠️ No data for {band}")
        continue

    arr = data[0]  # first image
    out_path = os.path.join(RAW_DIR, f"{band}.tif")

    # Save cleanly with rasterio
    transform = from_origin(min_lon, max_lat, (max_lon-min_lon)/512, (max_lat-min_lat)/512)
    with rasterio.open(
        out_path, 'w',
        driver='GTiff',
        height=arr.shape[0],
        width=arr.shape[1],
        count=1,
        dtype=arr.dtype,
        crs="EPSG:4326",
        transform=transform
    ) as dst:
        dst.write(arr, 1)

    print(f"✅ Saved {band} directly as {out_path}")
