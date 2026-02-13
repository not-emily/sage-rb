#!/bin/bash
set -e

VERSION=$(ruby -r ./lib/sage/version -e "puts Sage::VERSION")

echo "=== Releasing sage-rb v${VERSION} ==="

# 1. Run tests
echo "--- Running tests ---"
bundle exec rspec

# 2. Build gem
echo "--- Building gem ---"
gem build sage-rb.gemspec

# 3. Verify template is included
if ! gem spec "sage-rb-${VERSION}.gem" files 2>/dev/null | grep -q "\.tt"; then
  echo "ERROR: .tt template not found in gem package!"
  exit 1
fi

# 4. Tag and push
echo "--- Tagging v${VERSION} ---"
git tag "v${VERSION}"
git push origin master
git push origin "v${VERSION}"

# 5. Push to RubyGems
echo "--- Publishing to RubyGems ---"
gem push "sage-rb-${VERSION}.gem"

# 6. Create GitHub release
echo "--- Creating GitHub release ---"
gh release create "v${VERSION}" \
  --title "v${VERSION}" \
  --notes "Release v${VERSION}"

echo "=== Done! sage-rb v${VERSION} released ==="
