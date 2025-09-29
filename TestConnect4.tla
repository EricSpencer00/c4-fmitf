--------------------------- MODULE TestConnect4 ---------------------------
(*
  Test module for Connect 4 specifications to verify correctness.
*)

EXTENDS Connect4Apalache, TLC

\* Test basic board operations
TestEmptyBoard ==
    LET empty == EmptyBoard
    IN /\ \A row \in 1..ROWS, col \in 1..COLS : empty[row][col] = EMPTY
       /\ ValidColumns(empty) = 1..COLS
       /\ ~PlayerWins(empty, PLAYER1)
       /\ ~PlayerWins(empty, PLAYER2)

\* Test move validity  
TestValidMoves ==
    LET empty == EmptyBoard
        move1 == DropPiece(empty, 1, 4, PLAYER1)  \* Drop in middle
    IN /\ DropRow(empty, 4) = 1
       /\ move1[1][4] = PLAYER1
       /\ DropRow(move1, 4) = 2  \* Next piece goes to row 2

\* Test win detection
TestWinDetection ==
    LET \* Create horizontal win for player 1
        board == [row \in 1..ROWS |-> [col \in 1..COLS |->
            IF row = 1 /\ col \in 1..4 THEN PLAYER1 ELSE EMPTY]]
    IN PlayerWins(board, PLAYER1)

\* Test canonical form  
TestCanonicalForm ==
    LET board == [row \in 1..ROWS |-> [col \in 1..COLS |->
            IF row = 1 /\ col = 1 THEN PLAYER1 ELSE EMPTY]]
        flipped == FlipHorizontal(board)
        canonical1 == CanonicalForm(board)
        canonical2 == CanonicalForm(flipped)
    IN canonical1 = canonical2  \* Same canonical form

\* Test game sequence
TestGameSequence ==
    LET moves == <<4, 4, 3, 3, 2, 2, 1>>  \* Should create win for player 1
        final == LET play[i \in 0..Len(moves)] ==
            IF i = 0 THEN EmptyBoard
            ELSE LET col == moves[i]
                     row == DropRow(play[i-1], col)
                     player == IF i % 2 = 1 THEN PLAYER1 ELSE PLAYER2
                 IN DropPiece(play[i-1], row, col, player)
        IN play[Len(moves)]
    IN PlayerWins(final, PLAYER1)

\* Run all tests
AllTests == 
    /\ TestEmptyBoard
    /\ TestValidMoves  
    /\ TestWinDetection
    /\ TestCanonicalForm
    /\ TestGameSequence

=============================================================================