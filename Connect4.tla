--------------------------- MODULE Connect4 ---------------------------
(*
  Connect 4 specification with a history of normalized boards.
  The live board and turn retain their original player identities.
*)

EXTENDS Integers, Sequences, FiniteSets

CONSTANTS
    ROWS,    \* Number of rows (typically 6)
    COLS,    \* Number of columns (typically 7)
    PLAYERS, \* Set of players {1, 2} where 1 = Red, 2 = Yellow
    MAX_MOVES \* TLC exploration bound; selected by the configuration

ASSUME /\ ROWS \in Nat \ {0}
       /\ COLS \in Nat \ {0}
       /\ PLAYERS = {1, 2}
       /\ MAX_MOVES \in Nat

VARIABLES
    board,      \* Current board state: [row][col] -> player or 0 (empty)
    turn,       \* Current player's turn
    gameOver,   \* Boolean indicating if game is finished
    winner,     \* Winner (0 = no winner/tie, 1 or 2 = player)
    moveCount,  \* Number of moves made
    normalizedBoards  \* Set of all normalized board states seen

\* Type annotations for Apalache
\* @type: Int;
TypeRowRange == 1..ROWS

\* @type: Int;  
TypeColRange == 1..COLS

\* @type: Int;
TypePlayer == 0..2

\* @type: Seq(Seq(Int));
TypeBoard == [TypeRowRange -> [TypeColRange -> TypePlayer]]

\* Board manipulation functions

\* @type: (Seq(Seq(Int))) => Seq(Seq(Int));
FlipBoardHorizontally(b) ==
    [row \in 1..ROWS |-> 
        [col \in 1..COLS |-> b[row][COLS + 1 - col]]]

\* @type: (Int) => Int;
SwapPlayer(p) == 
    IF p = 1 THEN 2 
    ELSE IF p = 2 THEN 1 
    ELSE 0

\* @type: (Seq(Seq(Int))) => Seq(Seq(Int));
SwapBoardColors(b) ==
    [row \in 1..ROWS |-> 
        [col \in 1..COLS |-> SwapPlayer(b[row][col])]]

\* Compare cells in row-major order; integer <= cannot compare boards.
BoardLessOrEqual(a, b) ==
    a = b \/
    \E row \in 1..ROWS, col \in 1..COLS :
        /\ a[row][col] < b[row][col]
        /\ \A r \in 1..ROWS, c \in 1..COLS :
            (r < row \/ (r = row /\ c < col)) => a[r][c] = b[r][c]

\* @type: (Seq(Seq(Int))) => Seq(Seq(Int));
NormalizeBoard(b) ==
    LET flipped == FlipBoardHorizontally(b)
        colorSwapped == SwapBoardColors(b)
        flippedAndSwapped == SwapBoardColors(flipped)
        candidates == {b, flipped, colorSwapped, flippedAndSwapped}
    IN CHOOSE normalized \in candidates : 
        \A other \in candidates : BoardLessOrEqual(normalized, other)

\* @type: (Seq(Seq(Int)), Int, Int) => Bool;
IsValidPosition(b, row, col) ==
    /\ row \in 1..ROWS
    /\ col \in 1..COLS
    /\ b[row][col] = 0

\* @type: (Seq(Seq(Int)), Int) => Int;
FindLowestEmptyRow(b, col) ==
    IF col \notin 1..COLS THEN 0
    ELSE LET validRows == {row \in 1..ROWS : b[row][col] = 0}
         IN IF validRows = {} THEN 0
            ELSE CHOOSE row \in validRows : \A r \in validRows : r <= row

\* @type: (Seq(Seq(Int)), Int, Int, Int) => Seq(Seq(Int));
PlacePiece(b, row, col, player) ==
    [r \in 1..ROWS |-> 
        [c \in 1..COLS |-> 
            IF r = row /\ c = col THEN player ELSE b[r][c]]]

\* Win condition checking

\* @type: (Seq(Seq(Int)), Int, Int, Int, Int, Int) => Bool;
CheckDirection(b, row, col, deltaRow, deltaCol, player) ==
    \A i \in 0..3 : 
        LET newRow == row + i * deltaRow
            newCol == col + i * deltaCol
        IN /\ newRow \in 1..ROWS
           /\ newCol \in 1..COLS  
           /\ b[newRow][newCol] = player

\* @type: (Seq(Seq(Int)), Int, Int, Int) => Bool;
CheckWinFromPosition(b, row, col, player) ==
    \/ CheckDirection(b, row, col, 0, 1, player)    \* Horizontal
    \/ CheckDirection(b, row, col, 1, 0, player)    \* Vertical  
    \/ CheckDirection(b, row, col, 1, 1, player)    \* Diagonal /
    \/ CheckDirection(b, row, col, 1, -1, player)   \* Diagonal \
    \/ CheckDirection(b, row, col, 0, -1, player)   \* Horizontal left
    \/ CheckDirection(b, row, col, -1, 0, player)   \* Vertical up
    \/ CheckDirection(b, row, col, -1, -1, player)  \* Diagonal \  up
    \/ CheckDirection(b, row, col, -1, 1, player)   \* Diagonal / up

\* @type: (Seq(Seq(Int)), Int) => Bool;
HasPlayerWon(b, player) ==
    \E row \in 1..ROWS, col \in 1..COLS :
        /\ b[row][col] = player
        /\ CheckWinFromPosition(b, row, col, player)

\* @type: (Seq(Seq(Int))) => Int;
GetWinner(b) ==
    IF HasPlayerWon(b, 1) THEN 1
    ELSE IF HasPlayerWon(b, 2) THEN 2
    ELSE 0

\* @type: (Seq(Seq(Int))) => Bool;
IsBoardFull(b) ==
    \A row \in 1..ROWS, col \in 1..COLS : b[row][col] \in {1, 2}

\* @type: (Seq(Seq(Int))) => Set(Int);
GetValidColumns(b) ==
    {col \in 1..COLS : FindLowestEmptyRow(b, col) > 0}

\* Initial state
Init ==
    /\ board = [row \in 1..ROWS |-> [col \in 1..COLS |-> 0]]
    /\ turn = 1
    /\ gameOver = FALSE
    /\ winner = 0
    /\ moveCount = 0
    /\ normalizedBoards = {NormalizeBoard(board)}

\* Make a move action
MakeMove(col) ==
    LET row == FindLowestEmptyRow(board, col)
        newBoard == PlacePiece(board, row, col, turn)
        newWinner == GetWinner(newBoard)
        newNormalized == NormalizeBoard(newBoard)
    IN /\ row > 0  \* Valid move
       /\ ~gameOver
       /\ board' = newBoard
       /\ turn' = IF turn = 1 THEN 2 ELSE 1
       /\ winner' = newWinner
       /\ gameOver' = (newWinner > 0 \/ IsBoardFull(newBoard))
       /\ moveCount' = moveCount + 1
       /\ normalizedBoards' = normalizedBoards \union {newNormalized}

\* Next state relation
Next ==
    \E col \in GetValidColumns(board) : MakeMove(col)

\* Specification
Spec == Init /\ [][Next]_<<board, turn, gameOver, winner, moveCount, normalizedBoards>>

\* A state constraint belongs in the .cfg, not in Next.
MoveLimit == moveCount <= MAX_MOVES

\* Properties to verify

\* Game eventually ends
GameEventuallyEnds == <>(gameOver = TRUE)

\* No invalid moves
ValidMoves == 
    [](\A col \in 1..COLS : 
        (~gameOver /\ FindLowestEmptyRow(board, col) > 0) => ENABLED MakeMove(col))

\* Winner consistency
WinnerConsistency == 
    [](gameOver /\ winner > 0 => HasPlayerWon(board, winner))

\* No duplicate normalized boards in reachable states
NoDuplicateStates == 
    \A b1, b2 \in normalizedBoards : 
        b1 = b2 \/ NormalizeBoard(b1) # NormalizeBoard(b2)

\* Replay a finite sequence. Row ROWS is the bottom of this board.
RECURSIVE PlaySequence(_)
PlaySequence(moves) ==
    IF Len(moves) = 0 THEN
        [row \in 1..ROWS |-> [col \in 1..COLS |-> 0]]
    ELSE LET previous == PlaySequence(SubSeq(moves, 1, Len(moves) - 1))
             col == moves[Len(moves)]
             row == FindLowestEmptyRow(previous, col)
             player == IF Len(moves) % 2 = 1 THEN 1 ELSE 2
         IN IF row > 0 /\ GetWinner(previous) = 0
            THEN PlacePiece(previous, row, col, player)
            ELSE previous

\* @type: (Seq(Int), Seq(Seq(Int))) => Bool;
IsValidGameSequence(moves, targetBoard) ==
    /\ moves \in [1..Len(moves) -> 1..COLS]
    /\ \A i \in 1..Len(moves) :
        LET previous == PlaySequence(SubSeq(moves, 1, i - 1))
        IN /\ GetWinner(previous) = 0
           /\ FindLowestEmptyRow(previous, moves[i]) > 0
    /\ NormalizeBoard(PlaySequence(moves)) = targetBoard

\* Finite enumeration for tiny boards only; expensive on a 6x7 board.
BoardReachability ==
    \A b \in normalizedBoards :
        \E moves \in UNION {[1..n -> 1..COLS] : n \in 0..(ROWS * COLS)} :
            IsValidGameSequence(moves, b)

\* History-size analysis predicate; not a state-space reduction invariant.
StateSpaceEfficiency ==
    LET totalPossibleBoards == 3^(ROWS * COLS)  \* Each cell can be 0, 1, or 2
        reachableBoards == Cardinality(normalizedBoards)
    IN reachableBoards * 4 <= totalPossibleBoards

\* Invariants
TypeInvariant ==
    /\ board \in TypeBoard
    /\ turn \in {1, 2}
    /\ gameOver \in BOOLEAN
    /\ winner \in {0, 1, 2}
    /\ moveCount \in 0..(ROWS * COLS)
    /\ normalizedBoards \subseteq TypeBoard

PieceCountConsistency ==
    moveCount = Cardinality({<<r, c>> \in (1..ROWS) \X (1..COLS) : board[r][c] # 0})

TurnConsistency == turn = IF moveCount % 2 = 0 THEN 1 ELSE 2

GravityInvariant ==
    \A row \in 1..(ROWS - 1), col \in 1..COLS :
        board[row][col] # 0 => board[row + 1][col] # 0

TerminalConsistency ==
    /\ winner = GetWinner(board)
    /\ gameOver = (winner > 0 \/ IsBoardFull(board))

MoveAvailability == ~gameOver => GetValidColumns(board) # {}

=============================================================================
