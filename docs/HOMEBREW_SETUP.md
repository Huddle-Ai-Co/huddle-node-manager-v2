# Setting Up Your Huddle Homebrew Tap

This guide will walk you through the process of creating and publishing the Huddle Homebrew tap for the IPFS Node Manager.

## Step 1: Create a GitHub Repository

1. Create a new GitHub repository named `homebrew-ipfs`
   - The prefix `homebrew-` is important for Homebrew taps
   - Example: https://github.com/huddle/homebrew-ipfs

2. Clone the repository locally:
   ```bash
   git clone https://github.com/huddle/homebrew-ipfs.git
   cd homebrew-ipfs
   ```

## Step 2: Prepare Your Formula

1. Create a Formula directory in your repository:
   ```bash
   mkdir -p Formula
   ```

2. Copy the formula file:
   ```bash
   cp /Users/perceptivefocus/ipfs-node-manager/Formula/ipfs-node-manager.rb Formula/
   ```

3. Copy the README:
   ```bash
   cp /Users/perceptivefocus/ipfs-node-manager/Formula/README.md ./README.md
   ```

## Step 3: Create a Release of Your IPFS Node Manager

1. Create a release on your IPFS Node Manager repository:
   - Tag it as `v1.0.0`
   - Generate a tarball of your code
   - GitHub will automatically create URLs like: 
     `https://github.com/huddle/ipfs-node-manager/archive/v1.0.0.tar.gz`

2. Calculate the SHA256 hash of your release tarball:
   ```bash
   curl -L https://github.com/huddle/ipfs-node-manager/archive/v1.0.0.tar.gz | shasum -a 256
   ```

3. Update the formula with the correct SHA256 hash:
   - Replace `REPLACE_WITH_ACTUAL_SHA256_AFTER_RELEASE` with the actual hash

## Step 4: Publish Your Tap

1. Commit and push the formula to your homebrew-ipfs repository:
   ```bash
   git add .
   git commit -m "Add Huddle ipfs-node-manager formula"
   git push origin main
   ```

## Step 5: Test Installation

1. Add your tap:
   ```bash
   brew tap huddle/ipfs
   ```

2. Install your formula:
   ```bash
   brew install ipfs-node-manager
   ```

3. Test that it works:
   ```bash
   ipfs-setup --help
   ```

## Step 6: Share with Users

Users can now install your tool with:

```bash
# One-time tap addition
brew tap huddle/ipfs

# Install the formula
brew install ipfs-node-manager
```

## Updating Your Formula

When you release new versions:

1. Create a new release on GitHub with a new tag (e.g., `v1.0.1`)
2. Update the formula with the new URL and SHA256
3. Commit and push the updated formula

Users can then update with:
```bash
brew update
brew upgrade ipfs-node-manager
``` 