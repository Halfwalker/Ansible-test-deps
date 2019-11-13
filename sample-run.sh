#!/bin/bash

echo "Running test.yml playbook with no tag selections"
./test.sh

echo ""
echo "----------------------------------------------------------------------------"
echo "Running test.yml with --tags 'z' to select all roles"
echo "Results 'should' be the same as without the --tags 'z' but aren't"
./test.sh --tags 'z'

echo ""
echo "----------------------------------------------------------------------------"
echo "Running test.yml with --tags 'c' to select just role C and dependencies"
./test.sh --tags 'c'

echo ""
echo "----------------------------------------------------------------------------"
echo "Running test.yml with --tags 'b,c' to select roles B and C and dependencies"
./test.sh --tags 'b,c'

