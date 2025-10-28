#!/bin/bash
# Discover and update models in opencode.json
set -e

CONFIG_FILE=".opencode/opencode.json"
BACKUP_FILE=".opencode/opencode.json.backup"

echo "🔍 Discovering models..."

# Backup
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"

# Fetch and format Ollama models
echo "📡 Querying Ollama..."
OLLAMA_MODELS=$(curl -s http://host.docker.internal:11434/api/tags | jq -r '
  reduce .models[] as $item ({}; 
    . + {($item.name): {name: $item.name}}
  ) | tostring
')

# Fetch and format LM Studio models  
echo "📡 Querying LM Studio..."
LMSTUDIO_MODELS=$(curl -s http://host.docker.internal:1234/v1/models | jq -r '
  reduce .data[] as $item ({}; 
    . + {($item.id): {name: ($item.id + " (local)")}}
  ) | tostring
')

echo "📝 Updating config..."

# First, fix the original JSON by removing trailing commas
jq 'walk(if type == "object" then del(.[] | select(. == "")) else . end)' "$CONFIG_FILE" > "${CONFIG_FILE}.fixed" && mv "${CONFIG_FILE}.fixed" "$CONFIG_FILE"

# Now update with the new models
jq --argjson ollama "$OLLAMA_MODELS" \
   --argjson lmstudio "$LMSTUDIO_MODELS" \
   '.provider.ollama.models = $ollama | 
    .provider.lmstudio.models = $lmstudio' \
   "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo "✅ Done! Models updated."
echo ""
echo "Ollama models: $(jq '.provider.ollama.models | length' "$CONFIG_FILE")"
echo "LM Studio models: $(jq '.provider.lmstudio.models | length' "$CONFIG_FILE")"