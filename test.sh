#!/bin/bash

# This script sends a POST request to the running Wikipedia Agent
# to fetch the summary for "General relativity".

# The Go server is expecting the topic as a plain text string
# in the request body, sent to the /lookup endpoint.
# The '-s' flag makes curl silent, so only the server response is printed.
curl -s -X POST \
  -H "Content-Type: text/plain" \
  -d "General relativity" \
  http://localhost:8080/lookup

# Add a newline at the end for cleaner terminal output
echo ""
