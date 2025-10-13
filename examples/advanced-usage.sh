#!/bin/bash

echo "=== Advanced Usage Examples for Slot Nonce Validator ==="
echo ""

echo "1. Testing different concurrency levels..."
echo ""

echo "   a) Low concurrency (5 concurrent requests):"
echo "   Command: hype run validate-nonces.lua -- --concurrency=5"
time hype run validate-nonces.lua -- --concurrency=5 --file=test-process-map.json

echo ""
echo "   b) Default concurrency (10 concurrent requests):"
echo "   Command: hype run validate-nonces.lua"
time hype run validate-nonces.lua -- --file=test-process-map.json

echo ""
echo "   c) High concurrency (20 concurrent requests):"
echo "   Command: hype run validate-nonces.lua -- --concurrency=20"
time hype run validate-nonces.lua -- --concurrency=20 --file=test-process-map.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "2. Verbose mode (detailed output)..."
echo "Command: hype run validate-nonces.lua -- --verbose --file=test-process-map.json"
echo ""
hype run validate-nonces.lua -- --verbose --file=test-process-map.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "3. Filter to show only mismatches..."
echo "Command: hype run validate-nonces.lua -- --only-mismatches --file=test-process-map.json"
echo ""
hype run validate-nonces.lua -- --only-mismatches --file=test-process-map.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "4. Combining multiple flags..."
echo "Command: hype run validate-nonces.lua -- --verbose --only-mismatches --concurrency=15"
echo ""
hype run validate-nonces.lua -- --verbose --only-mismatches --concurrency=15 --file=test-process-map.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "5. Performance comparison..."
echo ""
echo "Timing different concurrency levels on test data:"
echo ""

echo "Sequential (concurrency=1):"
time hype run validate-nonces.lua -- --concurrency=1 --only-mismatches --file=test-process-map.json

echo ""
echo "Low concurrency (concurrency=5):"
time hype run validate-nonces.lua -- --concurrency=5 --only-mismatches --file=test-process-map.json

echo ""
echo "High concurrency (concurrency=20):"
time hype run validate-nonces.lua -- --concurrency=20 --only-mismatches --file=test-process-map.json

echo ""
echo "All advanced examples completed!"
