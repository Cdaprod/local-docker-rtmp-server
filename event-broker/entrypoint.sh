#!/bin/bash

# Health check script for metadata enricher service
curl --fail --silent http://localhost:5000/health || exit 1