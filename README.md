# Connect 4 Apalache Specification

This directory contains highly optimized TLA+ specifications for Connect 4, designed for efficient state space exploration with Apalache.

## Files Overview

### Core Specifications

1. **`Connect4.tla`** - Basic Connect 4 specification with state normalization
2. **`Connect4Apalache.tla`** - Apalache-optimized version with better type annotations  
3. **`Connect4Optimized.tla`** - Ultra-optimized with bit-packed board representation
4. **`TestConnect4.tla`** - Test harness for verification
5. **`Connect4Analysis.tla`** - State space analysis and metrics

### Configuration Files

- **`Connect4.cfg`** - TLC configuration for basic specification
- **`Connect4Apalache.cfg`** - Apalache configuration with bounded checking
- **`Connect4Optimized.cfg`** - Configuration for optimized version

## Key Optimizations

### 1. State Space Reduction (75% reduction)

The specifications use **canonical board representation** to eliminate equivalent states:

- **Horizontal symmetry**: Board flipped left-right
- **Color symmetry**: Player colors swapped  
- **Combined**: Both transformations applied

This reduces the state space by up to 75% by storing only the lexicographically smallest representation among all equivalent boards.

### 2. Reachability-Only States

Only boards reachable through valid Connect 4 gameplay are generated:
- Pieces must obey gravity (no floating pieces)
- Alternating player turns
- Valid column placement only

### 3. Efficient Data Structures

**Connect4Optimized.tla** uses bit-packed board representation:
- 2 bits per cell (empty=00, player1=01, player2=10)
- 6×7 board = 84 bits total
- Faster comparisons and canonical form computation

### 4. Early Termination

Games terminate immediately upon:
- Four-in-a-row detection
- Board full (draw)
- No valid moves remaining

## Running the Specifications

### With Apalache (Recommended)

```bash
# Install Apalache
# Download from: https://github.com/informalsystems/apalache

# Minimal smoke test (init only)
apalache-mc check --config=Connect4Apalache.apalache.cfg --length=0 --inv=TypeOK Connect4Apalache.tla

# Explore a few moves with core invariants
apalache-mc check --config=Connect4Apalache.apalache.cfg --length=4 --inv=TypeOK,ValidGameState Connect4Apalache.tla

# Include symmetry and physics invariants (heavier)
apalache-mc check --config=Connect4Apalache.apalache.cfg --length=6 --inv=TypeOK,ValidGameState,StateSpaceReduction,NoImpossiblePositions Connect4Apalache.tla

# If Apalache needs more JVM heap (example: 8 GiB)
APALACHE_JAVA_OPTS="-Xmx8G" apalache-mc check --config=Connect4Apalache.apalache.cfg --length=6 --inv=TypeOK,ValidGameState Connect4Apalache.tla
```

### With TLC

```bash
# Install TLA+ tools
# Download from: https://lamport.azurewebsites.net/tla/tools.html

# Run model checking
tlc Connect4.tla -config Connect4.cfg

# With larger state space
tlc Connect4.tla -config Connect4.cfg -constraint "moveCount <= 20"
```

## Performance Characteristics

### State Space Comparison

| Approach | States (6×7 board) | Reduction Factor |
|----------|-------------------|------------------|
| Naive    | 3^42 ≈ 1.6×10^20  | 1x              |
| Reachable only | ~10^12 | ~10^8x |
| + Canonical forms | ~2.5×10^11 | ~4x additional |
| **Total reduction** | | **~4×10^8x** |

### Memory Usage

- **Standard representation**: 84 bits per board
- **Canonical storage**: Same size, fewer unique boards
- **Compression ratio**: ~4:1 minimum from symmetry reduction

## Example Usage

### Exploring Game Trees

```tla
\* Find all positions reachable in 10 moves
Init /\ moveCount <= 10

\* Analyze opening positions  
OpeningPositions(6)  \* All positions after 6 moves

\* Check for forced wins
\E board : CanForceWin(board, PLAYER1)
```

### Verification Properties

```tla
\* Games always terminate
<>(gameOver = TRUE)

\* No invalid board states
[]ValidStates

\* Canonical forms work correctly  
[]StateSpaceReduction
```

## State Space Analysis

The `Connect4Analysis.tla` module provides metrics:

- **Total possible boards**: 3^42 ≈ 1.59×10^20
- **Estimated reachable**: ~10^12 (considering game rules)
- **After optimization**: ~2.5×10^11 (4x reduction from symmetries)
- **Compression ratio**: ~640,000:1 vs naive approach

## Advanced Features

### Canonical Form Algorithm

1. Generate 4 symmetric variants of each board:
   - Original
   - Horizontally flipped  
   - Color-swapped
   - Both flipped and color-swapped

2. Choose lexicographically smallest as canonical form

3. Store only canonical forms in state space

### Bit-Packed Representation (Connect4Optimized.tla)

```tla
\* Pack board into single integer
packedBoard = Σ(cell_value * 2^(position*2))

\* Extract cell value
GetCell(packed, row, col) = (packed ÷ 2^shift) mod 4

\* Set cell value  
SetCell(packed, row, col, value) = (packed with bits cleared) + new_value
```

## Testing

Run the test suite:

```bash
tlc TestConnect4.tla -config TestConnect4.cfg
```

Tests verify:
- Basic board operations
- Move validity
- Win detection  
- Canonical form correctness
- Game sequence simulation

## Contributing

When modifying specifications:

1. Maintain type annotations for Apalache compatibility
2. Preserve canonical form properties
3. Add tests for new functionality
4. Update performance analysis

## References

- [Apalache Documentation](https://apalache.informal.systems/)
- [TLA+ Language Manual](https://lamport.azurewebsites.net/tla/book.html)
- [Connect 4 Complexity Analysis](https://tromp.github.io/c4/c4.html)

```
apalache-mc check --config=Connect4Apalache.apalache.cfg --length=0 --inv=TypeOK Connect4Apalache.tla
```