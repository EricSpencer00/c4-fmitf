-------------------------- MODULE TestConnect4 --------------------------
EXTENDS Connect4

EmptyBoard == [r \in 1..ROWS |-> [c \in 1..COLS |-> 0]]

TestEmptyBoard ==
    /\ GetValidColumns(EmptyBoard) = 1..COLS
    /\ ~HasPlayerWon(EmptyBoard, 1)
    /\ ~HasPlayerWon(EmptyBoard, 2)

TestValidMoves ==
    LET first == PlacePiece(EmptyBoard, ROWS, 4, 1)
        fullColumn == [r \in 1..ROWS |-> [c \in 1..COLS |-> IF c = 4 THEN 1 ELSE 0]]
    IN /\ FindLowestEmptyRow(EmptyBoard, 4) = ROWS
       /\ first[ROWS][4] = 1
       /\ FindLowestEmptyRow(first, 4) = ROWS - 1
       /\ FindLowestEmptyRow(fullColumn, 4) = 0
       /\ FindLowestEmptyRow(EmptyBoard, 0) = 0
       /\ FindLowestEmptyRow(EmptyBoard, COLS + 1) = 0

TestWinDetection ==
    LET horizontal == [r \in 1..ROWS |-> [c \in 1..COLS |->
            IF r = ROWS /\ c \in 1..4 THEN 1 ELSE 0]]
        vertical == [r \in 1..ROWS |-> [c \in 1..COLS |->
            IF c = 1 /\ r \in (ROWS - 3)..ROWS THEN 2 ELSE 0]]
        diagonal == [r \in 1..ROWS |-> [c \in 1..COLS |->
            IF c \in 1..4 /\ r = ROWS + 1 - c THEN 1 ELSE 0]]
        reverseDiagonal == FlipBoardHorizontally(diagonal)
        three == PlacePiece(horizontal, ROWS, 4, 0)
    IN /\ GetWinner(horizontal) = 1
       /\ GetWinner(vertical) = 2
       /\ GetWinner(diagonal) = 1
       /\ GetWinner(reverseDiagonal) = 1
       /\ GetWinner(three) = 0
       /\ ~CheckDirection(horizontal, ROWS, COLS, 0, 1, 1)

TestCanonicalForm ==
    LET b == PlacePiece(EmptyBoard, ROWS, 1, 1)
        canonical == NormalizeBoard(b)
    IN /\ canonical = NormalizeBoard(FlipBoardHorizontally(b))
       /\ canonical = NormalizeBoard(SwapBoardColors(b))
       /\ canonical = NormalizeBoard(FlipBoardHorizontally(SwapBoardColors(b)))
       /\ canonical = NormalizeBoard(canonical)
       /\ \A other \in {b, FlipBoardHorizontally(b), SwapBoardColors(b),
                        FlipBoardHorizontally(SwapBoardColors(b))} :
            BoardLessOrEqual(canonical, other)

TestGameSequence ==
    LET moves == <<4, 4, 3, 3, 2, 2, 1>>
        final == PlaySequence(moves)
    IN /\ GetWinner(final) = 1
       /\ IsValidGameSequence(moves, NormalizeBoard(final))
       /\ ~IsValidGameSequence(Append(moves, 5), NormalizeBoard(final))
       /\ ~IsValidGameSequence(<<0>>, EmptyBoard)

AllTests == /\ TestEmptyBoard
            /\ TestValidMoves
            /\ TestWinDetection
            /\ TestCanonicalForm
            /\ TestGameSequence

TestInit == Init
TestNext == UNCHANGED <<board, turn, gameOver, winner, moveCount, normalizedBoards>>

\* Negative controls for the TLC state-constraint boundary.
WithinMoveLimit == MoveLimit
GuardedNext == Next /\ MoveLimit'
=============================================================================
