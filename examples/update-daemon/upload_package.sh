#!/usr/bin/env bash
set -euo pipefail

file_path="$1"
token="$2"
project_name="$3"
file_name="$(basename "$file_path")"

# Log size
echo "Uploading file: $file_name"
ls -l "$file_path"

response=$(curl -s \
  -X POST "https://example.com/update" \
  -H "Accept: */*" \
  -H "User-Agent: Deployment" \
  -H "x-authorization: $token" \
  -H "x-filename: $file_name" \
  -H "x-project: $project_name" \
  -F "file=@${file_path};filename=${file_name}" \
)

echo "Response:"
echo "$response"
