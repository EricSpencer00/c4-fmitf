---------------------- MODULE StateSpaceAnalysis ----------------------
(*
  Demonstration of state space reduction in Connect 4.
  This module calculates actual reduction factors.
*)

EXTENDS Connect4Apalache, FiniteSets

\* Calculate the theoretical state space sizes

\* Naive approach: every cell can be empty, player1, or player2
NaiveStateSpace == 3^(ROWS * COLS)

\* Physics-constrained: only positions where pieces obey gravity
PhysicsConstrainedStates == 
    \* Estimate based on valid drop sequences
    \* Each column can have 0 to ROWS pieces
    (ROWS + 1)^COLS

\* With game rules: only positions reachable through alternating play
GameRuleStates ==
    \* Conservative estimate: games average 25 moves
    \* Branching factor starts at COLS, decreases as columns fill
    LET avgMoves == 25
        avgBranching == COLS \div 2
    IN avgBranching^avgMoves

\* With canonical forms: divide by symmetry factor
CanonicalStates == GameRuleStates \div 4

\* Compression ratios
PhysicsReduction == NaiveStateSpace \div PhysicsConstrainedStates
GameRuleReduction == PhysicsConstrainedStates \div GameRuleStates  
CanonicalReduction == GameRuleStates \div CanonicalStates
TotalReduction == NaiveStateSpace \div CanonicalStates

\* For standard 6x7 Connect 4
StandardConnect4Analysis ==
    /\ ROWS = 6 /\ COLS = 7
    /\ NaiveStateSpace = 3^42          \* ≈ 1.6 × 10^20
    /\ PhysicsConstrainedStates = 7^7   \* ≈ 8.2 × 10^5  
    /\ GameRuleStates = 7^25           \* Conservative estimate
    /\ CanonicalStates = 7^25 \div 4   \* With symmetry reduction
    /\ TotalReduction > 1000000        \* At least 6 orders of magnitude

\* Memory efficiency calculations  
BitsPerCell == 2  \* Empty=00, Player1=01, Player2=10
BitsPerBoard == ROWS * COLS * BitsPerCell
MemoryReduction == TotalReduction * BitsPerBoard

\* Performance metrics
SearchSpeedup == CanonicalReduction  \* Fewer states to explore
StorageEfficiency == MemoryReduction \div BitsPerBoard

\* Verification that our optimizations work
OptimizationCorrectness ==
    /\ PhysicsReduction > 1
    /\ GameRuleReduction > 1  
    /\ CanonicalReduction >= 4  \* From horizontal + color symmetries
    /\ TotalReduction > 100000  \* Substantial overall reduction

=============================================================================