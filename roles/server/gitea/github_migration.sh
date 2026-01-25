#!/bin/bash

# This script was used to list all the repos in my Github account
# and create a mirror in Gitea

GITHUB_USERNAME="your-github-username"
# GitHub Personal Access Token - Create one at https://github.com/settings/tokens
# (needs repo scope for private repos, or just public_repo for public ones)
GITHUB_TOKEN="your-github-token"

GITEA_URL="https://your-gitea-instance.com"
# Gitea API Token - Create one in your Gitea instance:
# Settings → Applications → Generate New Token
GITEA_TOKEN="your-gitea-token"
GITEA_UID=1  # Your Gitea user ID (check via /api/v1/user)

# curl -X GET "$GITEA_URL/api/v1/user" \
# -H "Authorization: token $GITEA_TOKEN" \
# -H "Content-Type: application/json" \

# Get all repos from GitHub (handles pagination up to 300 repos)
for page in 1 2 3; do
    repos=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" \
        "https://api.github.com/user/repos?per_page=100&page=$page&affiliation=owner")

    echo "$repos" | jq -c '.[]' | while read -r repo; do
        name=$(echo "$repo" | jq -r '.name')
        clone_url=$(echo "$repo" | jq -r '.clone_url')
        private=$(echo "$repo" | jq -r '.private')

        echo "Mirroring: $name"

        curl -s -X POST "$GITEA_URL/api/v1/repos/migrate" \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
        \"clone_addr\": \"$clone_url\",
        \"auth_username\": \"$GITHUB_USERNAME\",
        \"auth_token\": \"$GITHUB_TOKEN\",
        \"repo_name\": \"$name\",
        \"uid\": $GITEA_UID,
        \"mirror\": true,
        \"private\": $private
        }"

        echo ""
    done
done
