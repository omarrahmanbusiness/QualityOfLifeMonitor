#!/bin/bash
# Simple script to start the local development server

echo "Starting Maria's IB Tutoring Website..."
echo "========================================"
echo ""
echo "Server will be available at:"
echo "  http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

cd "$(dirname "$0")"
python3 -m http.server 8000
