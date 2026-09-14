import os, sys, datetime
import rasterio
from sentinelhub import SHConfig, BBox, CRS, SentinelHubRequest, MimeType, DataCollection, SentinelHubCatalog

# ===== Args =====
if len(sys.argv) != 6:
    print("❌ Usage: python3 fetch_bands_daily.py <regionName> <minLon> <minLat> <maxLon> <maxLat>")
    sys.exit(1)

region = sys.argv[1]
minLon, minLat, maxLon, maxLat = map(float, sys.argv[2:])

# ===== Config =====
config = SHConfig()
if not config.sh_client_id or not config.sh_client_secret:
    raise RuntimeError("❌ Missing SentinelHub credentials in environment")

BASE_DIR = os.path.expanduser("~/Desktop/VistaProject/raw_data")
REGION_DIR = os.path.join(BASE_DIR, region)
os.makedirs(REGION_DIR, exist_ok=True)

bbox = BBox([minLon, minLat, maxLon, maxLat], crs=CRS.WGS84)

# ===== Time range: 1 year =====
end_date = datetime.date.today()
start_date = end_date - datetime.timedelta(days=365)

# ===== Catalog query =====
catalog = SentinelHubCatalog(config=config)
search_iterator = catalog.search(
    DataCollection.SENTINEL2_L2A,
    bbox=bbox,
    time=(str(start_date), str(end_date)),
    filter="eo:cloud_cover < 30",  # ✅ CQL2 filter
    fields={"include": ["id", "properties.datetime"], "exclude": []}
)

scenes = list(search_iterator)
print(f"📡 Found {len(scenes)} acquisitions between {start_date} → {end_date}")

bands = ["B01", "B02", "B03", "B04", "B08", "B11", "B12"]

# ===== Loop over acquisitions =====
for idx, scene in enumerate(scenes):
    dt_full = scene["properties"]["datetime"]
    dt = dt_full[:10]  # YYYY-MM-DD
    print(f"\n⏳ Fetching {dt} ({idx+1}/{len(scenes)})")

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
                time_interval=(dt, dt),   # single day
                mosaicking_order="leastCC"
            )],
            responses=[SentinelHubRequest.output_response("default", MimeType.TIFF)],
            bbox=bbox,
            size=(512, 512),
            config=config
        )
try:
    data = request.get_data()
    if data:
        arr = data[0]

        # handle multiple acquisitions per day with counter
        counter = sum(1 for f in os.listdir(REGION_DIR) if f.startswith(f"{band}_{dt}"))
        suffix = f"_{counter+1}" if counter else ""
        out_path = os.path.join(REGION_DIR, f"{band}_{dt}{suffix}.tif")

        # ✅ Use from_bounds instead of get_transform()
        from rasterio.transform import from_bounds
        transform = from_bounds(minLon, minLat, maxLon, maxLat, arr.shape[1], arr.shape[0])

        with rasterio.open(
            out_path, "w",
            driver="GTiff",
            height=arr.shape[0],
            width=arr.shape[1],
            count=1,
            dtype=arr.dtype,
            crs=bbox.crs.pyproj_crs(),
            transform=transform
        ) as dst:
            dst.write(arr, 1)

        print(f"   ✅ {band} saved → {out_path}")
    else:
        print(f"   ⚠️ No data for {band} on {dt}")
except Exception as e:
    print(f"   ❌ Error fetching {band} on {dt}: {e}")
