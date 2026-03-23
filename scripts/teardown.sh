#!/bin/bash
# Destroys the cluster for a clean slate.

echo "Deleting Kind cluster 'monitoring-lab'..."
kind delete cluster --name monitoring-lab
echo "Done. Everything is gone."
