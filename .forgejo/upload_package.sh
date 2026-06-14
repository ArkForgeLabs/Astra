#!/usr/bin/env bash
set -euo pipefail

server_path="$1"
file_path="$2"
token="$3"
project_name="$4"
file_name="$(basename "$file_path")"

# Log size
echo "Uploading file: $file_name to $server_path"
ls -l "$file_path"

response=$(curl -s \
  -X POST $server_path \
  -H "Accept: */*" \
  -H "User-Agent: Deployment" \
  -H "x-authorization: $token" \
  -H "x-filename: $file_name" \
  -H "x-project: $project_name" \
  -F "file=@${file_path};filename=${file_name}" \
)

echo "Response:"
echo "$response"
