# CI/CD Setup Guide

This document explains how to configure the CI/CD pipeline for automatic TestFlight builds on every Pull Request.

## Overview

The pipeline uses:
- **GitHub Actions** - For CI/CD automation
- **Fastlane** - For iOS build and TestFlight upload
- **App Store Connect API** - For authentication with Apple services

## Required GitHub Secrets

Navigate to your repository's **Settings > Secrets and variables > Actions** and add the following secrets:

### Code Signing Secrets

| Secret Name | Description | How to Get It |
|-------------|-------------|---------------|
| `APPLE_CERTIFICATE_P12` | Base64 encoded distribution certificate (.p12) | Export from Keychain Access, then base64 encode |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the .p12 certificate | The password you set when exporting |
| `KEYCHAIN_PASSWORD` | Temporary keychain password for CI | Generate a random secure password |

### Provisioning Profile Secrets

| Secret Name | Description |
|-------------|-------------|
| `PROVISIONING_PROFILE_APP` | Base64 encoded App Store profile for main app |
| `PROVISIONING_PROFILE_SHIELD_ACTION` | Profile for ShieldAction extension |
| `PROVISIONING_PROFILE_SHIELD_CONFIG` | Profile for ShieldConfig extension |
| `PROVISIONING_PROFILE_DEVICE_ACTIVITY_REPORT` | Profile for DeviceActivityReport extension |
| `PROVISIONING_PROFILE_DEVICE_ACTIVITY_MONITOR` | Profile for DeviceActivityMonitor extension |

### App Store Connect API Secrets

| Secret Name | Description |
|-------------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | The Key ID from App Store Connect |
| `APP_STORE_CONNECT_API_ISSUER_ID` | The Issuer ID from App Store Connect |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Base64 encoded .p8 API key file content |

## Step-by-Step Setup

### 1. Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access > Integrations > App Store Connect API**
3. Click the **+** button to create a new key
4. Give it a name (e.g., "CI/CD Key")
5. Select **Admin** or **App Manager** access
6. Download the `.p8` file (you can only download it once!)
7. Note the **Key ID** and **Issuer ID**

To encode the API key:
```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

### 2. Export Distribution Certificate

1. Open **Keychain Access** on your Mac
2. Find your "Apple Distribution" certificate
3. Right-click and select **Export**
4. Save as `.p12` format and set a strong password
5. Encode it:
```bash
base64 -i Certificates.p12 | pbcopy
```

### 3. Download Provisioning Profiles

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles > Profiles**
3. Download App Store provisioning profiles for:
   - `com.luminote.screentime` (main app)
   - `com.luminote.screentime.ShieldAction`
   - `com.luminote.screentime.ShieldConfig`
   - `com.luminote.screentime.DeviceActivityReport`
   - `com.luminote.screentime.DeviceActivityMonitor`

4. Encode each profile:
```bash
base64 -i profile.mobileprovision | pbcopy
```

### 4. Create Required Profiles (If They Don't Exist)

If the provisioning profiles don't exist, you'll need to create them:

1. Go to **Identifiers** and ensure all App IDs exist with proper capabilities:
   - Family Controls entitlement
   - App Groups: `group.com.luminote.screentime`

2. Go to **Profiles** and create an **App Store** profile for each identifier

### 5. Add Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to **Settings > Secrets and variables > Actions**
3. Click **New repository secret**
4. Add each secret listed above

## How the Pipeline Works

### Trigger Events

The pipeline runs on:
- **Pull Requests** to `main` or `master` branches
- **Pushes** to `main` or `master` branches
- **Manual trigger** via workflow_dispatch

### Build Process

1. Checks out the code
2. Selects Xcode 15.4
3. Sets up Ruby and installs Fastlane
4. Creates a temporary keychain
5. Imports signing certificate
6. Installs provisioning profiles
7. Generates a unique build number (timestamp-based)
8. Builds the app using Fastlane
9. Uploads to TestFlight
10. Posts a comment on the PR with build details

### Build Numbers

Build numbers are automatically generated using the format: `YYYYMMDDHHMM`

Example: `202601081430` (January 8, 2026 at 14:30)

You can override this with a manual workflow run.

## Local Development

### Running Fastlane Locally

```bash
# Install dependencies
bundle install

# Run tests
bundle exec fastlane test

# Build for TestFlight (requires local signing)
bundle exec fastlane beta
```

### Using Match (Optional)

For easier certificate management, you can use [fastlane match](https://docs.fastlane.tools/actions/match/):

1. Create a private GitHub repository for certificates
2. Update the `MATCH_GIT_URL` in `fastlane/Matchfile`
3. Run `bundle exec fastlane match appstore` to generate/sync certificates

## Troubleshooting

### Common Issues

**Build fails with signing errors:**
- Verify all provisioning profiles are correctly encoded and uploaded
- Ensure the certificate hasn't expired
- Check that all App IDs have the required capabilities

**TestFlight upload fails:**
- Verify App Store Connect API key has correct permissions
- Check that the API key hasn't been revoked
- Ensure the Issuer ID and Key ID are correct

**Build number already exists:**
- Wait a minute and re-run (build numbers are time-based)
- Or use the workflow_dispatch with a custom build number

### Logs

- Check **Actions** tab in GitHub for workflow logs
- Look for the `fastlane.log` output in the build step

## Security Notes

- Never commit secrets to the repository
- Rotate API keys periodically
- Use repository environments for production vs staging (optional)
- The temporary keychain is deleted after each build

## Files Reference

| File | Purpose |
|------|---------|
| `.github/workflows/testflight.yml` | GitHub Actions workflow |
| `fastlane/Fastfile` | Fastlane automation lanes |
| `fastlane/Appfile` | App configuration |
| `fastlane/Matchfile` | Code signing configuration (optional) |
| `Gemfile` | Ruby dependencies |
