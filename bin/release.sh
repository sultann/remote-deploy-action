#!/bin/bash
set -e

# Get current tags
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
MAJOR_TAG=""

if [ -n "$CURRENT_TAG" ]; then
  echo "Current version: $CURRENT_TAG"
  MAJOR_TAG=$(echo "$CURRENT_TAG" | cut -d. -f1)
  echo "Major version tag: $MAJOR_TAG"
else
  echo "No existing tags found"
fi

# Ask for new version
read -p "Enter new version (e.g., v1.0.3): " NEW_VERSION

# Validate version format
if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "✗ Invalid version format. Use v1.0.3"
  exit 1
fi

# Extract major version
NEW_MAJOR=$(echo "$NEW_VERSION" | cut -d. -f1)

# Confirm release
echo ""
echo "Creating release: $NEW_VERSION"
read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Release cancelled"
  exit 0
fi

# Create and push tag
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"
git push origin "$NEW_VERSION"
echo "✓ Created and pushed tag: $NEW_VERSION"

# Handle major version tag
if [ -n "$MAJOR_TAG" ] && [ "$MAJOR_TAG" != "$NEW_MAJOR" ]; then
  echo ""
  echo "Major version changed from $MAJOR_TAG to $NEW_MAJOR"
  read -p "Create new major tag $NEW_MAJOR? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git tag -fa "$NEW_MAJOR" -m "Release $NEW_MAJOR"
    git push -f origin "$NEW_MAJOR"
    echo "✓ Created major tag: $NEW_MAJOR"
  fi
elif [ "$MAJOR_TAG" == "$NEW_MAJOR" ]; then
  echo ""
  echo "Major tag $MAJOR_TAG exists and points to: $(git rev-list -n 1 $MAJOR_TAG | cut -c1-7)"
  read -p "Move $MAJOR_TAG to this release? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git tag -fa "$MAJOR_TAG" -m "Update $MAJOR_TAG to $NEW_VERSION"
    git push -f origin "$MAJOR_TAG"
    echo "✓ Updated major tag: $MAJOR_TAG"
  fi
elif [ -z "$MAJOR_TAG" ]; then
  echo ""
  read -p "Create major tag $NEW_MAJOR? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git tag -a "$NEW_MAJOR" -m "Release $NEW_MAJOR"
    git push origin "$NEW_MAJOR"
    echo "✓ Created major tag: $NEW_MAJOR"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Release $NEW_VERSION complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"