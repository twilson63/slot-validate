#!/bin/bash

echo "=== Basic Usage Examples for Slot Nonce Validator ==="
echo ""

echo "1. Running with test data (5 processes)..."
echo "Command: hype run validate-nonces.lua -- --file=test-process-map.json"
echo ""
hype run validate-nonces.lua -- --file=test-process-map.json

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "2. Running with full data (all processes in process-map.json)..."
echo "Command: hype run validate-nonces.lua"
echo ""
hype run validate-nonces.lua

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "3. Show only mismatches..."
echo "Command: hype run validate-nonces.lua -- --only-mismatches"
echo ""
hype run validate-nonces.lua -- --only-mismatches

echo ""
echo "All basic examples completed!"
