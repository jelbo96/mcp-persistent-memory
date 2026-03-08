#!/usr/bin/env bash
set -euo pipefail

API="http://localhost:18000"
USER_ID="ignaciojelvez"
NAMESPACE="agent"
REPO="$(basename "$(git rev-parse --show-toplevel)")"
SESSION_ID="repo:${REPO}"

HASH="$(git rev-parse HEAD)"
SHORT_HASH="$(git rev-parse --short HEAD)"
MSG="$(git log -1 --pretty=%B | tr '\n' ' ' | sed 's/"/\\"/g')"
FILES="$(git diff-tree --no-commit-id --name-only -r "$HASH" | tr '\n' ', ' | sed 's/,$//')"
AUTHOR="$(git log -1 --pretty=%an)"
DATE="$(git log -1 --pretty=%aI)"

curl -sS -X POST "${API}/v1/long-term-memory/" \
  -H "Content-Type: application/json" \
  -d "{
    \"memories\": [
      {
        \"id\": \"git-${HASH}\",
        \"text\": \"[${REPO}] Commit ${SHORT_HASH}: ${MSG}. Archivos modificados: ${FILES}\",
        \"memory_type\": \"episodic\",
        \"topics\": [\"git\", \"commits\", \"cambios\"],
        \"entities\": [\"${REPO}\"],
        \"user_id\": \"${USER_ID}\",
        \"session_id\": \"${SESSION_ID}\",
        \"namespace\": \"${NAMESPACE}\"
      }
    ],
    \"deduplicate\": true
  }" > /dev/null 2>&1 || true
