// Initialize the map (Leaflet)
const map = L.map('map').setView([28.20, 77.55], 10); // Center on Rabupura by default

// Add OpenStreetMap tiles
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors'
}).addTo(map);

// Draw control for selecting AOI
const drawnItems = new L.FeatureGroup();
map.addLayer(drawnItems);

const drawControl = new L.Control.Draw({
    draw: {
        polygon: true,
        rectangle: true,
        circle: false,
        marker: false,
        circlemarker: false,
        polyline: false
    },
    edit: {
        featureGroup: drawnItems
    }
});
map.addControl(drawControl);

// Handle AOI selection
map.on(L.Draw.Event.CREATED, function (e) {
    drawnItems.clearLayers(); // keep only one AOI
    const layer = e.layer;
    drawnItems.addLayer(layer);

    // Get bounding box of AOI
    const bounds = layer.getBounds();
    const minLat = bounds.getSouthWest().lat;
    const minLon = bounds.getSouthWest().lng;
    const maxLat = bounds.getNorthEast().lat;
    const maxLon = bounds.getNorthEast().lng;

    console.log("📌 Selected BBox:", minLon, minLat, maxLon, maxLat);

    // Ask region name
    const regionName = prompt("Enter a name for this region:", "MyRegion") || "CustomRegion";

    // Send to backend
    fetch("http://127.0.0.1:5001/run_pipeline", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            region: regionName,
            bbox: [minLon, minLat, maxLon, maxLat]
        })
    })
    .then(res => res.json())
    .then(data => {
        alert("✅ Pipeline executed for " + regionName + "\nCheck processed_data folder!");
        console.log("Backend response:", data);
    })
    .catch(err => {
        console.error("❌ Backend error:", err);
        alert("❌ Failed to connect to backend. Is Flask running?");
    });
});
