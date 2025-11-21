#!/bin/bash

set -euo pipefail

# =============================================================================
# Remote Deploy Action
# =============================================================================
# Deploys files to remote server via SSH and rsync
# =============================================================================

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "::error::$1"
}

log_warning() {
    echo "::warning::$1"
}

# -----------------------------------------------------------------------------
# Input Validation
# -----------------------------------------------------------------------------
if [[ -z "$TARGET_PATH" ]]; then
    log_error "TARGET_PATH is required"
    exit 1
fi

if [[ -z "$SOURCE_PATH" ]]; then
    log_error "SOURCE_PATH is required"
    exit 1
fi

# -----------------------------------------------------------------------------
# Prepare Remote Path
# -----------------------------------------------------------------------------
log_info "Preparing remote path on $REMOTE_HOST..."
if ssh remote-server "mkdir -p '$TARGET_PATH'"; then
    log_info "Remote path ensured: $TARGET_PATH"
else
    log_error "Failed to create remote path"
    exit 1
fi

# -----------------------------------------------------------------------------
# Build Exclusion List
# -----------------------------------------------------------------------------
RSYNC_EXCLUDE_ARGS=(
    "--exclude=node_modules/"
)

if [[ -n "${IGNORE_FILE:-}" && -f "$GITHUB_WORKSPACE/$IGNORE_FILE" ]]; then
    log_info "Reading exclusions from: $IGNORE_FILE"
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^! ]]; then
            pattern="${line#!}"
            RSYNC_EXCLUDE_ARGS+=("--include=$pattern")
        else
            RSYNC_EXCLUDE_ARGS+=("--exclude=$line")
        fi
    done < "$GITHUB_WORKSPACE/$IGNORE_FILE"
fi

# -----------------------------------------------------------------------------
# Dry Run Check
# -----------------------------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "Dry run mode - no actual deployment"
    RSYNC_DRY_RUN="--dry-run"
else
    RSYNC_DRY_RUN=""
fi

# -----------------------------------------------------------------------------
# Deploy Files via Rsync
# -----------------------------------------------------------------------------
log_info "Deploying files via rsync..."
log_info "Source: $SOURCE_PATH"
log_info "Target: $REMOTE_HOST:$TARGET_PATH"
log_info "Options: $RSYNC_OPTIONS"
echo ""

RSYNC_OPTS=${RSYNC_OPTIONS:--avz --delete}

rsync $RSYNC_OPTS $RSYNC_DRY_RUN \
    --no-o --no-g \
    "${RSYNC_EXCLUDE_ARGS[@]}" \
    "$GITHUB_WORKSPACE/$SOURCE_PATH" \
    "remote-server:$TARGET_PATH"

if [[ $? -eq 0 ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run completed successfully"
        log_info "No files were actually deployed (dry-run mode)"
    else
        log_info "Files deployed successfully"
    fi
else
    log_error "Rsync deployment failed"
    exit 1
fi

# -----------------------------------------------------------------------------
# Run Script After Deployment
# -----------------------------------------------------------------------------
if [[ -n "$SCRIPT_AFTER" && "$DRY_RUN" != "true" ]]; then
    log_info "Running post-deployment script on remote server..."

    if ssh remote-server "cd '$TARGET_PATH' && $SCRIPT_AFTER"; then
        log_info "Post-deployment script completed successfully"
    else
        log_warning "Post-deployment script failed (non-fatal)"
    fi
fi

# -----------------------------------------------------------------------------
# Success
# -----------------------------------------------------------------------------
log_info ""
log_info "=== Deployment Complete ==="
log_info "Target: $REMOTE_HOST:$TARGET_PATH"
