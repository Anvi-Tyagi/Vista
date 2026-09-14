#!/bin/bash
# Usage:
#   ./run_full_pipeline.sh Amritsar 74.75 31.5 75.1 31.7

if [ $# -lt 5 ]; then
  echo "❌ Usage: ./run_full_pipeline.sh <regionName> <minLon> <minLat> <maxLon> <maxLat>"
  exit 1
fi

REGION=$1
MINLON=$2
MINLAT=$3
MAXLON=$4
MAXLAT=$5

cd ~/Desktop/VistaProject/sentinel
source venv/bin/activate

echo "📡 Fetching Sentinel-2 data for $REGION..."
python3 fetch_bands.py $REGION $MINLON $MINLAT $MAXLON $MAXLAT

echo "🧮 Running MATLAB pipeline for $REGION..."
/Applications/MATLAB_R2025a.app/bin/matlab -batch "cd('~/Desktop/VistaProject/matlab_scripts'); run_pipeline('$REGION'); exit;"

echo "✅ Done! Outputs in processed_data/$REGION and reports/"
