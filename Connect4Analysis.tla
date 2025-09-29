------------------------- MODULE Connect4Analysis -------------------------
(*
  Analysis module for Connect 4 state space exploration and optimization metrics.
*)

EXTENDS Connect4Apalache, FiniteSets

\* State space analysis

\* Total possible board configurations (theoretical maximum)
TotalPossibleBoards == 3^(ROWS * COLS)  \* Each cell: empty, player1, player2

\* Estimate reachable boards through valid gameplay  
EstimateReachableBoards ==
    \* Conservative estimate: games last 7-42 moves, branching factor ~7 initially
    \* Many positions unreachable due to physics (gravity) and game rules
    LET avgGameLength == (7 + 42) \div 2  \* ~25 moves average
        avgBranching == 4  \* Average valid columns as game progresses
        estimate == avgBranching^avgGameLength
    IN Min(estimate, TotalPossibleBoards)
    
\* Symmetry reduction factor
SymmetryReductionFactor ==
    \* Horizontal flip + color swap gives 4-fold reduction theoretical max
    4

\* Expected state space after optimization
OptimizedStateSpace == 
    EstimateReachableBoards \div SymmetryReductionFactor

\* Analysis of specific game positions

\* Opening positions after n moves
OpeningPositions(n) ==
    {board \in [1..ROWS -> [1..COLS -> {EMPTY, PLAYER1, PLAYER2}]] :
        /\ \E seq \in Seq(1..COLS) : 
            /\ Len(seq) = n
            /\ IsValidGameSequence(seq, board)
        /\ board = CanonicalForm(board)}

\* @type: (Seq(Int), Seq(Seq(Int))) => Bool;        
IsValidGameSequence(moves, result) ==
    LET play[i \in 0..Len(moves)] ==
        IF i = 0 THEN EmptyBoard
        ELSE LET col == moves[i]
                 row == DropRow(play[i-1], col)
                 player == IF i % 2 = 1 THEN PLAYER1 ELSE PLAYER2
             IN IF row > 0 THEN DropPiece(play[i-1], row, col, player)
                ELSE play[i-1]
    IN CanonicalForm(play[Len(moves)]) = result

\* Game tree analysis
GameTreeDepth(board) ==
    \* Maximum possible moves from current position
    ROWS * COLS - Sum({1 : row \in 1..ROWS, col \in 1..COLS, 
                       board[row][col] # EMPTY})

BranchingFactor(board) ==
    \* Number of valid moves from current position  
    Cardinality(ValidColumns(board))

\* Endgame analysis
IsEndgamePosition(board) ==
    \* Position is near end if few moves remain or forced win exists
    \/ GameTreeDepth(board) <= 10
    \/ \E player \in {PLAYER1, PLAYER2} : 
        CanForceWin(board, player)

\* @type: (Seq(Seq(Int)), Int) => Bool;        
CanForceWin(board, player) ==
    \* Simplified forced win detection (threats)
    \E col \in ValidColumns(board) :
        LET row == DropRow(board, col)
            newBoard == DropPiece(board, row, col, player)
        IN PlayerWins(newBoard, player)

\* Efficiency metrics for our optimization

\* Memory efficiency: bits per position
BitsPerPosition ==
    \* Standard representation: 2 bits per cell
    2 * ROWS * COLS

\* Compression ratio achieved
CompressionRatio ==
    \* Compare canonical storage vs naive storage
    LET naiveStorage == TotalPossibleBoards * BitsPerPosition
        canonicalStorage == OptimizedStateSpace * BitsPerPosition
    IN naiveStorage \div canonicalStorage

\* Search efficiency improvement
SearchSpeedupFactor ==
    \* Reduced branching due to canonical forms
    SymmetryReductionFactor

\* Practical analysis for 6x7 Connect 4

Connect4Stats ==
    /\ TotalPossibleBoards = 3^42  \* ~1.59 * 10^20
    /\ ROWS * COLS = 42
    /\ BitsPerPosition = 84
    /\ SymmetryReductionFactor = 4

\* Properties to verify our analysis

AnalysisCorrectness ==
    /\ OptimizedStateSpace < TotalPossibleBoards
    /\ SymmetryReductionFactor > 1
    /\ CompressionRatio > 1
    /\ SearchSpeedupFactor >= SymmetryReductionFactor

=============================================================================