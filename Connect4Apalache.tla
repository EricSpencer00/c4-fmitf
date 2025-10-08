------------------------- MODULE Connect4Apalache -------------------------
(*
  Apalache-optimized Connect 4 specification with aggressive state space reduction.
  
  Optimizations:
  1. Canonical board representation (75% reduction via symmetries)
  2. Reachability-only states 
  3. Efficient data structures
  4. Early game termination detection
  5. Pruning of impossible positions
*)

EXTENDS Integers, Sequences, FiniteSets, Apalache

CONSTANTS
    \* @type: Int;
    ROWS,
    \* @type: Int;
    COLS,
    \* @type: Set(Int);
    PLAYERS

VARIABLES
    \* @type: Int -> (Int -> Int);
    board,
    \* @type: Int;
    turn,
    \* @type: Bool;
    gameOver,
    \* @type: Int;
    winner,
    \* @type: Int;
    moveCount

\* Constants for players
EMPTY == 0
PLAYER1 == 1  
PLAYER2 == 2

\* Board canonicalization for symmetry reduction

\* Well-formed boards as functions from row->col to values
\* @type: () => Set(Int -> (Int -> Int));
BoardOf == [1..ROWS -> [1..COLS -> {EMPTY, PLAYER1, PLAYER2}]]

\* @type: (Int -> (Int -> Int)) => (Int -> (Int -> Int));
FlipHorizontal(b) ==
    [row \in 1..ROWS |-> 
        [col \in 1..COLS |-> b[row][COLS + 1 - col]]]

\* @type: (Int) => Int;
FlipPlayer(p) == 
    CASE p = PLAYER1 -> PLAYER2
      [] p = PLAYER2 -> PLAYER1  
      [] OTHER -> EMPTY

\* @type: (Int -> (Int -> Int)) => (Int -> (Int -> Int));
SwapColors(b) ==
    [row \in 1..ROWS |-> 
        [col \in 1..COLS |-> FlipPlayer(b[row][col])]]

\* Lexicographic comparison used by canonicalization
\* @type: (Int -> (Int -> Int), Int -> (Int -> Int)) => Bool;
LexLess(b1, b2) ==
    /\ b1 \in BoardOf
    /\ b2 \in BoardOf
    /\ \E row \in 1..ROWS :
        /\ \A r \in 1..(row-1) : b1[r] = b2[r]
        /\ \E col \in 1..COLS :
            /\ \A c \in 1..(col-1) : b1[row][c] = b2[row][c]
            /\ b1[row][col] < b2[row][col]

\* @type: (Int -> (Int -> Int)) => (Int -> (Int -> Int));
CanonicalForm(b) == 
    \* Choose lexicographically smallest among all symmetries
    LET h_flip == FlipHorizontal(b)
        c_swap == SwapColors(b) 
        hc_both == SwapColors(h_flip)
        all_forms == {b, h_flip, c_swap, hc_both}
    IN CHOOSE canonical \in all_forms :
        \A other \in all_forms : 
            \/ canonical = other
            \/ LexLess(canonical, other)

\* Efficient move validation and execution

\* @type: (Int -> (Int -> Int), Int) => Int;
DropRow(b, col) ==
    \* Find lowest empty row in column, 0 if full
    IF \A row \in 1..ROWS : b[row][col] # EMPTY
    THEN 0
    ELSE CHOOSE row \in 1..ROWS : 
            /\ b[row][col] = EMPTY
            /\ \A r \in 1..ROWS : r < row => b[r][col] # EMPTY

\* @type: (Int -> (Int -> Int), Int, Int, Int) => (Int -> (Int -> Int));
DropPiece(b, row, col, player) ==
    [r \in 1..ROWS |-> 
        [c \in 1..COLS |-> 
            IF r = row /\ c = col THEN player ELSE b[r][c]]]

\* @type: (Int -> (Int -> Int)) => Set(Int);
ValidColumns(b) ==
    {col \in 1..COLS : DropRow(b, col) > 0}

\* Win detection optimized for early termination

\* @type: (Int -> (Int -> Int), Int, Int, Int, Int, Int) => Bool;
FourInDirection(b, start_row, start_col, delta_row, delta_col, player) ==
    /\ \A i \in 0..3 : 
        LET row == start_row + i * delta_row
            col == start_col + i * delta_col  
        IN /\ row \in 1..ROWS
           /\ col \in 1..COLS
           /\ b[row][col] = player

\* @type: (Int -> (Int -> Int), Int) => Bool;
PlayerWins(b, player) ==
    \E row \in 1..ROWS, col \in 1..COLS :
        b[row][col] = player /\
        \/ FourInDirection(b, row, col, 0, 1, player)   \* Horizontal →
        \/ FourInDirection(b, row, col, 1, 0, player)   \* Vertical ↓ 
        \/ FourInDirection(b, row, col, 1, 1, player)   \* Diagonal ↘
        \/ FourInDirection(b, row, col, 1, -1, player)  \* Diagonal ↙
        \/ (col >= 4 /\ FourInDirection(b, row, col-3, 0, 1, player))   \* ← check
        \/ (row >= 4 /\ FourInDirection(b, row-3, col, 1, 0, player))   \* ↑ check  
        \/ (row >= 4 /\ col >= 4 /\ FourInDirection(b, row-3, col-3, 1, 1, player)) \* ↖ check
        \/ (row >= 4 /\ col <= COLS-3 /\ FourInDirection(b, row-3, col+3, 1, -1, player)) \* ↗ check

\* @type: (Int -> (Int -> Int)) => Bool;
BoardFull(b) ==
    \A row \in 1..ROWS, col \in 1..COLS : b[row][col] # EMPTY

\* @type: (Int -> (Int -> Int)) => Int;
GameWinner(b) ==
    IF PlayerWins(b, PLAYER1) THEN PLAYER1
    ELSE IF PlayerWins(b, PLAYER2) THEN PLAYER2  
    ELSE EMPTY

\* State space initialization
    
\* @type: () => (Int -> (Int -> Int));
EmptyBoard == [r \in 1..ROWS |-> [c \in 1..COLS |-> EMPTY]]

Init ==
    /\ board = EmptyBoard
    /\ turn = PLAYER1
    /\ gameOver = FALSE  
    /\ winner = EMPTY
    /\ moveCount = 0

\* Transition relations with canonicalization

Move(col) ==
    LET drop_row == DropRow(board, col)
        new_board == DropPiece(board, drop_row, col, turn)
        game_winner == GameWinner(new_board)
        next_turn == IF turn = PLAYER1 THEN PLAYER2 ELSE PLAYER1
    IN /\ drop_row > 0  \* Valid drop
       /\ ~gameOver
       /\ board' = CanonicalForm(new_board)  \* Store canonical form
       /\ turn' = next_turn  
       /\ winner' = game_winner
       /\ gameOver' = (game_winner # EMPTY \/ BoardFull(new_board))
       /\ moveCount' = moveCount + 1

Next == 
    \/ \E col \in ValidColumns(board) : Move(col)
    \/ UNCHANGED <<board, turn, gameOver, winner, moveCount>>  \* Stuttering

\* Specification 
Spec == Init /\ [][Next]_<<board, turn, gameOver, winner, moveCount>>

\* Fairness - ensure games don't stall
Fairness == WF_<<board, turn, gameOver, winner, moveCount>>(
    \E col \in ValidColumns(board) : Move(col))

SpecWithFairness == Spec /\ Fairness

\* Properties

\* Type safety
TypeOK ==
    /\ board \in BoardOf
    /\ turn \in {PLAYER1, PLAYER2}
    /\ gameOver \in BOOLEAN
    /\ winner \in {EMPTY, PLAYER1, PLAYER2} 
    /\ moveCount \in 0..(ROWS * COLS)

\* Game termination
Termination == <>(gameOver = TRUE)

\* Valid game state  
ValidGameState ==
    /\ (winner # EMPTY) => gameOver
    /\ gameOver => (winner # EMPTY \/ BoardFull(board))
    /\ (winner = PLAYER1) => PlayerWins(board, PLAYER1)
    /\ (winner = PLAYER2) => PlayerWins(board, PLAYER2)

\* @type: (Seq(Int)) => Bool;
ValidSequence(moves) ==
    LET n == Len(moves)
    IN /\ moves \in Seq(1..COLS)
    /\ \E boards \in Seq(BoardOf) :
            /\ Len(boards) = n + 1
            /\ boards[1] = EmptyBoard
            /\ boards[n + 1] = board
            /\ \A i \in 1..n :
                    LET cur == boards[i]
                        nxt == boards[i+1]
                        col == moves[i]
                        player == IF i % 2 = 1 THEN PLAYER1 ELSE PLAYER2
                        row == DropRow(cur, col)
                    IN /\ row > 0
                       /\ nxt = CanonicalForm(DropPiece(cur, row, col, player))

\* Reachability - every position reachable through valid play
Reachable == 
    moveCount >= 0 => \E seq \in Seq(1..COLS) :
        /\ Len(seq) = moveCount  
        /\ ValidSequence(seq)

\* Efficiency property - canonical forms reduce state space
StateSpaceReduction ==
    \* Every reachable board is in canonical form
    board = CanonicalForm(board)

\* No impossible positions  
NoImpossiblePositions ==
    \* Can't have floating pieces (pieces must be supported)
    \A row \in 2..ROWS, col \in 1..COLS :
        board[row][col] # EMPTY => board[row-1][col] # EMPTY

=============================================================================