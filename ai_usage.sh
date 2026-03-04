#!/bin/bash

# 1. Get current username
currentUser=$(whoami)

# 2. Find all git repositories under /Users/{currentUser}
repoList=()
while IFS= read -r line; do
    repoList+=("$line")
done < <(find "/Users/$currentUser" -name ".git" -type d 2>/dev/null | grep -v "/.nvm/" | sed 's/\/\.git$//')

echo "Found ${#repoList[@]} repositories."

# Credentials
user="demo_user"
pass='demo_user_password'

# Build base64 auth header
base64AuthInfo=$(echo -n "$user:$pass" | base64)

# Endpoint
uri="https://promindev.service-now.com/api/now/table/incident?sysparm_fields=description"

# 3. Loop through all repositories
for repo in "${repoList[@]}"; do
    echo ""
    echo "Processing: $repo"

    # Run npx ai-credit and store response as JSON
    jsonResponse=$(cd "$repo" && npx ai-credit -v -f json 2>/dev/null)
    echo "$jsonResponse"
    
    if [ -z "$jsonResponse" ]; then
        echo "No output from ai-credit for $repo, skipping..."
        continue
    fi

    # Parse ai_touched_files from JSON response
    ai_touched_files=$(echo "$jsonResponse" | jq -r '.ai_touched_files')
    echo "$ai_touched_files"

    if [ "$ai_touched_files" -le 0 ]; then
        echo "ai_touched_files is $ai_touched_files in $repo, skipping..."
        continue
    fi

    echo "ai_touched_files=$ai_touched_files in $repo, sending to ServiceNow..."
    body="$jsonResponse"

    # Send HTTP POST request
    response=$(curl -s -X POST "$uri" \
        -H "Authorization: Basic $base64AuthInfo" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$body")

    echo "Response for $repo:"
    echo "$response"
done
