#!/bin/bash

set -e

# Configuration
GHCR_REGISTRY="ghcr.io"
LOCAL_REGISTRY="localhost:5000"
REPOSITORY_NAME="${GITHUB_REPOSITORY:-iam-jawad/devops-assessment}"
IMAGE_NAME="robot-app"
FULL_IMAGE_NAME="${GHCR_REGISTRY}/${REPOSITORY_NAME}/${IMAGE_NAME}"
LOCAL_IMAGE_NAME="${LOCAL_REGISTRY}/${IMAGE_NAME}"
LOG_FILE="/var/log/image-sync.log"

# Function to log messages
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    # Write to log file
    echo "$msg" >> "$LOG_FILE"
    # Also show on console as STDERR (so it doesn't interfere with command substitutions)
    >&2 echo "$msg"
}

# Function to get all available tags from remote registry
get_remote_tags() {
    local image="$1"
    
    log "Fetching available tags for ${image}"
    
    # Extract registry, namespace and repo from image name
    # Format: ghcr.io/jawad/devops-assessment/robot-app
    local registry=$(echo "$image" | cut -d'/' -f1)
    local namespace_repo=$(echo "$image" | cut -d'/' -f2-)
    
    # Use GHCR API to get tags
    local api_url="https://${registry}/v2/${namespace_repo}/tags/list"
    local token_url="https://${registry}/token?scope=repository:${namespace_repo}:pull"
    
    log "Querying API: $api_url"
    
    # Get anonymous token for public repository
    local token=$(curl -s "$token_url" | jq -r '.token // empty' 2>/dev/null || echo "")
    
    local auth_header=""
    if [ -n "$token" ]; then
        auth_header="-H \"Authorization: Bearer $token\""
        log "Using anonymous token for public repository"
    elif [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_ACTOR" ]; then
        auth_header="-H \"Authorization: Bearer $GITHUB_TOKEN\""
        log "Using provided GitHub token"
    else
        log "No authentication available, trying without auth"
    fi
    
    local response=$(eval "curl -s $auth_header \"$api_url\"" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        log "Failed to get tags from API - no response received"
        return 1
    fi
    
    # Check for errors in response
    local error_check=$(echo "$response" | jq -r '.errors[]?.code?' 2>/dev/null || echo "")
    if [ -n "$error_check" ]; then
        log "API returned error: $error_check"
        return 1
    fi
    
    # Extract tags from JSON response
    local tags=$(echo "$response" | jq -r '.tags[]?' 2>/dev/null || echo "")
    
    if [ -z "$tags" ]; then
        log "No tags found in repository yet"
        return 1
    fi
    
    # Filter out signature tags (ending with .sig)
    local filtered_tags=$(echo "$tags" | grep -v '\.sig$' || echo "")
    
    if [ -z "$filtered_tags" ]; then
        log "No valid image tags found (only signatures detected)"
        return 1
    fi
    
    log "Found tags: $(echo "$filtered_tags" | tr '\n' ' ')"
    echo "$filtered_tags"
}

# Function to get remote image digest
get_remote_digest() {
    local image="$1"
    local tag="$2"

    log "Fetching digest for ${image}:${tag}"

    # Use --verbose so we always get Descriptor, even for manifest lists
    local manifest
    manifest=$(docker manifest inspect --verbose "${image}:${tag}" 2>/dev/null || echo "")

    if [ -z "$manifest" ]; then
        log "Failed to get manifest for ${image}:${tag}"
        return 1
    fi

    # Try several known shapes: array/object, Descriptor, config.digest, fallback .digest
    local digest
    digest=$(echo "$manifest" | jq -r '
      if type=="array" then
        # GHCR often wraps --verbose output in an array
        .[0].Descriptor.digest // empty
      elif has("Descriptor") then
        .Descriptor.digest // empty
      elif has("config") and .config.digest != null then
        .config.digest
      else
        .digest // empty
      end
    ')

    if [ -z "$digest" ] || [ "$digest" = "null" ]; then
        log "No digest found in manifest"
        return 1
    fi

    echo "$digest"
}

# Function to get local image digest
get_local_digest() {
    local image="$1"
    local tag="$2"

    # Check if the image exists in the local registry
    if ! docker manifest inspect --verbose "${image}:${tag}" >/dev/null 2>&1; then
        # Not present locally
        echo ""
        return 0
    fi

    local manifest
    manifest=$(docker manifest inspect --verbose "${image}:${tag}" 2>/dev/null || echo "")

    if [ -z "$manifest" ]; then
        echo ""
        return 0
    fi

    local digest
    digest=$(echo "$manifest" | jq -r '
      if type=="array" then
        .[0].Descriptor.digest // empty
      elif has("Descriptor") then
        .Descriptor.digest // empty
      elif has("config") and .config.digest != null then
        .config.digest
      else
        .digest // empty
      end
    ')

    if [ -z "$digest" ] || [ "$digest" = "null" ]; then
        echo ""
    else
        echo "$digest"
    fi
}

# Function to verify image signature
verify_signature() {
    local image="$1"
    local tag="$2"
    
    log "Verifying signature for ${image}:${tag}"
    
    # Use cosign to verify the signature with tag (not digest)
    local verify_output
    verify_output=$(cosign verify "${image}:${tag}" \
        --certificate-identity-regexp=".*" \
        --certificate-oidc-issuer-regexp=".*" 2>&1)
    local verify_result=$?
    
    if [ $verify_result -eq 0 ]; then
        log "✅ Signature verification successful"
        return 0
    else
        log "❌ Signature verification failed with exit code $verify_result"
        log "❌ Cosign output: $verify_output"
        return 1
    fi
}

# Function to pull and tag image
pull_and_tag() {
    local remote_image="$1"
    local local_image="$2"
    local tag="$3"
    
    log "Pulling ${remote_image}:${tag}"
    
    if docker pull "${remote_image}:${tag}"; then
        log "Successfully pulled ${remote_image}:${tag}"
        
        # Tag for local registry
        log "Tagging as ${local_image}:${tag}"
        docker tag "${remote_image}:${tag}" "${local_image}:${tag}"
        
        # Push to local registry
        log "Pushing to local registry: ${local_image}:${tag}"
        
        if docker push "${local_image}:${tag}"; then
            log "✅ Successfully synced ${tag} to local registry"
            return 0
        else
            log "❌ Failed to push ${local_image}:${tag} to local registry"
            return 1
        fi
    else
        log "❌ Failed to pull ${remote_image}:${tag}"
        return 1
    fi
}

# Function to sync images
sync_images() {
    log "Starting image sync process..."

    # Get all available tags from remote registry
    available_tags=$(get_remote_tags "$FULL_IMAGE_NAME")

    if [ $? -ne 0 ] || [ -z "$available_tags" ]; then
        log "No images found in repository yet. Will check again in next sync cycle."
        return 0
    fi

    log "Will sync the following tags: $(echo "$available_tags" | tr '\n' ' ')"
    log "Debug: available_tags variable content: '$available_tags'"
    log "Debug: available_tags line count: $(echo "$available_tags" | wc -l)"

    # Process each available tag
    local tag_count=0
    local sync_count=0

    while IFS= read -r tag; do
        [ -z "$tag" ] && continue

        log "Debug: Processing tag: '$tag'"
        tag_count=$((tag_count + 1))

        log "Checking tag: $tag"

        # Get remote digest
        remote_digest=$(get_remote_digest "$FULL_IMAGE_NAME" "$tag")
        if [ $? -ne 0 ] || [ -z "$remote_digest" ]; then
            log "Could not get remote digest for $tag, skipping..."
            continue
        fi

        # Get local digest
        local_digest=$(get_local_digest "$LOCAL_IMAGE_NAME" "$tag")

        log "Remote digest: $remote_digest"
        log "Local digest: $local_digest"

        # Check if we need to sync
        if [ "$remote_digest" != "$local_digest" ]; then
            log "🔄 New image detected for tag $tag"

            # Verify signature before pulling
            if verify_signature "$FULL_IMAGE_NAME" "$tag"; then
                # Pull and tag the image
                if pull_and_tag "$FULL_IMAGE_NAME" "$LOCAL_IMAGE_NAME" "$tag"; then
                    log "✅ Successfully synchronized $tag"
                    sync_count=$((sync_count + 1))
                else
                    log "❌ Failed to synchronize $tag"
                fi
            else
                log "❌ Skipping $tag due to signature verification failure"
            fi
        else
            log "📦 Tag $tag is already up to date"
        fi
    done <<< "$available_tags"

    log "Image sync process completed - processed $tag_count tags, synced $sync_count images"
}

# Function to cleanup old images
cleanup_old_images() {
    log "Cleaning up old images..."
    docker system prune -f >/dev/null 2>&1 || true
    log "Cleanup completed"
}

# Main execution
main() {
    log "=== Starting image synchronization ==="
    log "Remote registry: $GHCR_REGISTRY"
    log "Local registry: $LOCAL_REGISTRY"
    log "Image: $FULL_IMAGE_NAME"
    
    # Attempt to login to GHCR (optional, for public repos this isn't needed)
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN" | docker login "$GHCR_REGISTRY" -u "$GITHUB_ACTOR" --password-stdin >/dev/null 2>&1 || true
    fi
    
    # Perform the sync
    sync_images
    
    # Cleanup
    cleanup_old_images
    
    log "=== Image synchronization completed ==="
}

# Run main function
main