document.getElementById("runPipelineBtn").addEventListener("click", () => {
  const payload = {
    region: "Rabupura",
    bbox: [77.55, 28.20, 77.65, 28.30]
  };

  fetch("http://127.0.0.1:5001/run_pipeline", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  })
  .then(res => res.json())
  .then(data => {
    console.log("Pipeline Response:", data);
    alert("✅ Pipeline run success for " + data.region);
  })
  .catch(err => {
    console.error("Error:", err);
    alert("❌ Failed to run pipeline");
  });
});
