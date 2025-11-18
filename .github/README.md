# GitHub Workflow for Robot App

This GitHub workflow automatically builds, signs, and deploys the robot application to GitHub Container Registry (GHCR).

## Features

- ✅ Manual trigger with version input (workflow_dispatch only)
- ✅ Multi-platform Docker image builds (linux/amd64, linux/arm64)
- ✅ Image signing with Cosign
- ✅ Push to GitHub Container Registry (GHCR)
- ✅ Build caching for faster builds
- ✅ No external secrets required

## Required Setup

### GitHub Container Registry (GHCR) Setup

1. **Enable GHCR for your repository:**
   - Go to your repository Settings
   - Navigate to "Actions" → "General"
   - Under "Workflow permissions", ensure "Read and write permissions" is selected
   - Check "Allow GitHub Actions to create and approve pull requests"

2. **Enable package creation (if needed):**
   - Go to your GitHub account/organization Settings
   - Navigate to "Packages" in the left sidebar
   - Ensure "Package creation" is enabled for repositories

3. **Make packages public (optional):**
   - After first successful build, go to your repository "Packages" tab
   - Click on the created package
   - Go to "Package settings"
   - Change visibility to "Public" if desired

No external secrets required! The workflow uses GitHub's built-in authentication.

## Workflow Triggers

### Manual Trigger Only
1. Go to GitHub Actions tab in your repository
2. Select "Build, Sign and Push Robot App" workflow
3. Click "Run workflow"
4. Enter the desired APP_VERSION (e.g., "1.0.0")
5. Click "Run workflow"

## Image Locations

After successful workflow execution, your images will be available at:

```
ghcr.io/YOUR_USERNAME/YOUR_REPO/robot-app:VERSION
ghcr.io/YOUR_USERNAME/YOUR_REPO/robot-app:latest
```

## Local Image Signature Verification

The workflow automatically signs the built images with Cosign. To verify signatures locally:

```bash
# Install cosign if not already installed
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Verify signature before pulling (replace with your actual image path)
cosign verify ghcr.io/YOUR_USERNAME/YOUR_REPO/robot-app:1.0.0 \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer-regexp=".*"
```

Successful verification will show output confirming the signature validity.

## Application Version Injection

The workflow injects the APP_VERSION into the container as an environment variable, which the Flask application reads using:

```python
def get_app_version():
    return os.environ.get('APP_VERSION', '1.0.0')
```

This version is displayed in the web interface and exposed as Prometheus metrics.

## Example Usage

**Manual deployment with specific version:**
- Trigger workflow manually with APP_VERSION "2.1.0"
- Image will be tagged as `ghcr.io/YOUR_USERNAME/YOUR_REPO/robot-app:2.1.0`

## Monitoring

The robot application includes Prometheus metrics at `/metrics` endpoint, including version information that will reflect the injected APP_VERSION.