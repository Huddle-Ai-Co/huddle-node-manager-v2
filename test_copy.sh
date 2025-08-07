#!/bin/bash
echo "Testing copy commands..."
mkdir -p ~/.local/lib/huddle-node-manager/testing
if [ -f "testing/test_installation_paths_dynamic.sh" ]; then
    echo "Found: testing/test_installation_paths_dynamic.sh"
    cp testing/test_installation_paths_dynamic.sh ~/.local/lib/huddle-node-manager/testing/
    echo "Copied: test_installation_paths_dynamic.sh"
else
    echo "NOT FOUND: testing/test_installation_paths_dynamic.sh"
fi
ls -la ~/.local/lib/huddle-node-manager/testing/
