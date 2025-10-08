#!/bin/bash

# Connect 4 TLA+ Specification Runner
# Usage: ./run_connect4.sh [apalache|tlc] [specification]

set -e

TOOL=${1:-apalache}
SPEC=${2:-Connect4Apalache}

echo "🎯 Running Connect 4 specification with $TOOL"
echo "📋 Specification: $SPEC.tla"

case $TOOL in
    "apalache")
        echo "🚀 Running with Apalache (SMT-based model checker)"
        
        # Check if Apalache is installed
        if ! command -v apalache-mc &> /dev/null; then
            echo "❌ Apalache not found. Please install from:"
            echo "   https://github.com/informalsystems/apalache/releases"
            exit 1
        fi
        
        # Run bounded model checking
        # If SKIP_SNOWCAT is set, run a best-effort transpile to skip the full
        # Apalache pipeline (this bypasses Snowcat/type checking). This is
        # useful for quick iteration, but note: it does NOT perform invariant
        # checking or bounded model checking. Use with caution.
        if [ "${SKIP_SNOWCAT}" = "1" ] || [ "${TOOL}" = "apalache-notype" ]; then
            echo "⚠️  SKIP_SNOWCAT set: parsing spec only (Snowcat/typecheck skipped)"
            apalache-mc parse ${SPEC}.tla
        else
            echo "🔍 Running bounded model checking (length=12)..."
            apalache-mc check --length=12 --inv=TypeOK,ValidGameState ${SPEC}.tla
        fi
        
        # Check state space reduction
        echo "🔍 Verifying state space reduction..."
        apalache-mc check --length=8 --inv=StateSpaceReduction ${SPEC}.tla
        
        # Look for counterexamples
        echo "🔍 Searching for property violations..."
        if [ "${SKIP_SNOWCAT}" = "1" ] || [ "${TOOL}" = "apalache-notype" ]; then
            echo "⚠️  Skipped: NoImpossiblePositions (requires full check with Snowcat)"
        else
            apalache-mc check --length=15 --inv=NoImpossiblePositions ${SPEC}.tla
        fi
        ;;

    "apalache-notype")
        echo "🚀 Running Apalache (transpile only, Snowcat skipped)"
        if ! command -v apalache-mc &> /dev/null; then
            echo "❌ Apalache not found. Please install from:"
            echo "   https://github.com/informalsystems/apalache/releases"
            exit 1
        fi
    echo "⚠️  Parsing ${SPEC}.tla (no type checking / no invariants)"
    apalache-mc parse ${SPEC}.tla
        ;;
        
    "tlc")
        echo "🚀 Running with TLC (explicit-state model checker)"
        
        # Check if TLC is installed
        if ! command -v tlc &> /dev/null; then
            echo "❌ TLC not found. Please install TLA+ tools from:"
            echo "   https://lamport.azurewebsites.net/tla/tools.html"
            exit 1
        fi
        
        # Run model checking with config file
        echo "🔍 Running model checking..."
        tlc ${SPEC}.tla -config ${SPEC}.cfg -workers auto
        ;;
        
    "explore")
        echo "🚀 Exploring Connect 4 behaviors"
        
        if ! command -v apalache-mc &> /dev/null; then
            echo "❌ Apalache not found for exploration"
            exit 1
        fi
        
        # Generate sample behaviors
        echo "🎮 Generating sample game behaviors..."
        apalache-mc simulate --length=20 --max-run=5 ${SPEC}.tla
        ;;
        
    "test")
        echo "🧪 Running test suite"
        
        if command -v tlc &> /dev/null; then
            echo "🔍 Running unit tests..."
            tlc TestConnect4.tla
        else
            echo "❌ TLC required for testing"
            exit 1
        fi
        ;;
        
    *)
        echo "❌ Unknown tool: $TOOL"
        echo "Usage: $0 [apalache|tlc|explore|test] [specification]"
        echo ""
        echo "Available specifications:"
        echo "  - Connect4 (basic)"
        echo "  - Connect4Apalache (optimized for Apalache)"
        echo "  - Connect4Optimized (ultra-optimized with bit packing)"
        echo ""
        echo "Examples:"
        echo "  $0 apalache Connect4Apalache"
        echo "  $0 tlc Connect4"
        echo "  $0 explore Connect4Apalache"
        echo "  $0 test"
        exit 1
        ;;
esac

echo "✅ Completed successfully!"

# Performance summary
if [ -f "${SPEC}.out" ]; then
    echo ""
    echo "📊 Performance Summary:"
    grep -i "states\|time\|memory" "${SPEC}.out" || true
fi