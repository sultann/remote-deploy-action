#!/bin/bash

set -euo pipefail

# Uncomment for debugging
# set -x

#########################################
# LOGGING FUNCTIONS
#########################################

log_info() {
  echo "✓ $1"
}

log_error() {
  echo "✗ $1" >&2
}

log_warning() {
  echo "⚠ $1"
}

#########################################
# VALIDATE REQUIRED VARIABLES
#########################################

if [[ -z "$TARGET_PATH" || "$TARGET_PATH" == "/" || ! "$TARGET_PATH" =~ ^[a-zA-Z0-9/_\.\-]+$ || "$TARGET_PATH" != */* ]]; then
  log_error "TARGET_PATH is invalid or unsafe: '$TARGET_PATH'"
  exit 1
fi

if [[ "$TARGET_PATH" == *".."* ]]; then
  log_error "TARGET_PATH cannot contain '..' (directory traversal): '$TARGET_PATH'"
  exit 1
fi

if [[ -z "$SOURCE_PATH" ]]; then
  log_error "SOURCE_PATH is required"
  exit 1
fi

# Make critical variables immutable
readonly TARGET_PATH
readonly SOURCE_PATH
readonly REMOTE_HOST
readonly IGNORE_FILE
readonly EXCLUDE_PATHS

#########################################
# PREPARE REMOTE PATH
#########################################

echo "→ Preparing remote path on $REMOTE_HOST..."
if ssh remote-server "mkdir -p '$TARGET_PATH'"; then
  log_info "Remote path ensured: $TARGET_PATH"
else
  log_error "Failed to create remote path. Exiting..."
  exit 1
fi

#########################################
# BUILD EXCLUSION LIST
#########################################

# Always exclude these (hardcoded sensible defaults)
DEFAULT_EXCLUSIONS=(
  # Node modules (never deploy this)
  'node_modules/'
)

# Build rsync exclude arguments from defaults
RSYNC_EXCLUDE_ARGS=()
for pattern in "${DEFAULT_EXCLUSIONS[@]}"; do
  RSYNC_EXCLUDE_ARGS+=("--exclude=$pattern")
done

# Add custom ignore file if it exists
if [[ -n "$IGNORE_FILE" && -f "$GITHUB_WORKSPACE/$IGNORE_FILE" ]]; then
  echo "→ Using ignore file: $IGNORE_FILE"
  RSYNC_EXCLUDE_ARGS+=("--exclude-from=$GITHUB_WORKSPACE/$IGNORE_FILE")
else
  echo "ℹ No ignore file found (${IGNORE_FILE:-not specified})"
fi

# Add manual exclude paths
if [[ -n "$EXCLUDE_PATHS" ]]; then
  echo "→ Adding manual exclusion paths..."
  # Split by comma or newline
  IFS=$',\n'
  for path in $EXCLUDE_PATHS; do
    # Trim whitespace
    path=$(echo "$path" | xargs)
    if [[ -n "$path" ]]; then
      RSYNC_EXCLUDE_ARGS+=("--exclude=$path")
      echo "   - $path"
    fi
  done
  unset IFS
fi

#########################################
# DRY RUN CHECK
#########################################

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "DRY RUN MODE - No actual deployment"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  RSYNC_DRY_RUN="--dry-run"
else
  RSYNC_DRY_RUN=""
fi

#########################################
# DEPLOY FILES VIA RSYNC
#########################################

echo ""
echo "→ Deploying files via rsync..."
echo "   Source: $SOURCE_PATH"
echo "   Target: $REMOTE_HOST:$TARGET_PATH"
echo "   Options: $RSYNC_OPTIONS"
echo ""

# Parse rsync options (default: -avz --delete)
RSYNC_OPTS=${RSYNC_OPTIONS:--avz --delete}

# Build final rsync command
rsync $RSYNC_OPTS $RSYNC_DRY_RUN \
  --no-o --no-g \
  "${RSYNC_EXCLUDE_ARGS[@]}" \
  "$GITHUB_WORKSPACE/$SOURCE_PATH" \
  "remote-server:$TARGET_PATH"

if [[ $? -eq 0 ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    log_info "Dry run completed successfully!"
    echo "ℹ No files were actually deployed (dry-run mode)"
  else
    echo ""
    log_info "Files deployed successfully!"
  fi
else
  echo ""
  log_error "Rsync deployment failed!"
  exit 1
fi

#########################################
# RUN SCRIPT AFTER DEPLOYMENT
#########################################

if [[ -n "$SCRIPT_AFTER" && "$DRY_RUN" != "true" ]]; then
  echo ""
  echo "→ Running post-deployment script on remote server..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if ssh remote-server "cd '$TARGET_PATH' && $SCRIPT_AFTER"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Post-deployment script completed successfully"
  else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warning "Post-deployment script failed (non-fatal)"
  fi
fi

#########################################
# FINAL SUMMARY
#########################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Deployment process completed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
