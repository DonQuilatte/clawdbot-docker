#!/bin/bash
# Test the enhanced agy-project with job tracking

set -e

echo "=== Testing Enhanced agy-project ==="
echo ""

# Test 1: Submit a simple job
echo "Test 1: Submit job for clawdbot analysis"
echo "Command: ./scripts/agy-project clawdbot 'list all scripts in this repo'"
echo ""
read -p "Press Enter to run..."
./scripts/agy-project clawdbot "list all scripts in this repo"

echo ""
echo "Waiting 5 seconds..."
sleep 5

# Test 2: Check status
echo ""
echo "Test 2: Check job status"
echo "Command: ./scripts/agy-project status"
echo ""
read -p "Press Enter to run..."
./scripts/agy-project status

# Test 3: View logs
echo ""
echo "Test 3: View job logs"
echo "Enter the job-id from the status output above"
read -p "Job ID: " JOB_ID
./scripts/agy-project logs "$JOB_ID"

echo ""
echo "=== Tests Complete ==="
echo ""
echo "Additional commands to try:"
echo "  ./scripts/agy-project attach $JOB_ID    # Attach to live session"
echo "  ./scripts/agy-project result $JOB_ID    # Get result (when complete)"
