# Connect 4 in TLA+

`Connect4.tla` models gravity, alternating turns, four-in-a-row wins, and draws. Rows run from the top (`1`) to the bottom (`ROWS`). A move places a piece in the lowest empty cell of a column. Winning and full boards end the game.

The TLC model keeps the board, turn, result, move count, and a history of normalized boards. Normalization chooses the lexicographically smallest board among the original, its horizontal reflection, its color swap, and the reflected color swap. The live board and turn keep their player identities. TLC fingerprints the complete state, including the history; normalization deduplicates the history entries rather than merging symmetric game states.

## Run with TLC

Use Java 11 or newer and [TLA+ tools v1.7.4](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4), the stable release used for the checks below. From the repository root:

```bash
curl -fL https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar -o tla2tools.jar
java -Xmx1g -jar tla2tools.jar -workers 1 -config Connect4.cfg Connect4.tla
```

`Connect4.cfg` explores a 6×7 board with `MAX_MOVES = 4`. It checks types, normalized-history uniqueness, piece counts, turns, gravity, winner and terminal-state consistency, and move availability. Four moves keeps the default check small enough to finish quickly.

For a deeper bounded search on the same board:

```bash
java -Xmx1g -jar tla2tools.jar -workers 1 -config Connect4Bounded20.cfg Connect4.tla
```

`Connect4Bounded20.cfg` sets `MAX_MOVES = 20`. Twenty moves explores more than the four-move default and still prunes the full game. Exhaustive exploration at this bound is a substantial computation. A reproducible sample of this configuration is:

```bash
java -Xmx1g -jar tla2tools.jar -workers 1 -config Connect4Bounded20.cfg -simulate num=20 -depth 22 -seed 1 Connect4.tla
```

An existing `tlc` wrapper can replace `java -Xmx1g -jar tla2tools.jar` in these commands. `-config` selects the model configuration.

## What the bound means

The specification defines the state predicate:

```tla
MoveLimit == moveCount <= MAX_MOVES
```

Each bounded `.cfg` names it:

```tla
CONSTRAINT MoveLimit
```

TLC generates successors from states that satisfy this constraint. It checks invariants on generated successors, including those that fail the constraint, and excludes those successors from further exploration. With `MAX_MOVES = 20`, an unfinished twenty-move position can therefore generate an invariant-checked twenty-first move. The move bound controls exploration; it is separate from the invariants being verified.

Adding `MoveLimit'` to `Next` changes which successors the specification generates. A state constraint keeps `Next` intact. The regression checks demonstrate the difference: a zero-move constraint checks the one-move successor, while a primed guard produces a deadlock at the empty board. See [TLC's configuration reference](https://github.com/tlaplus/vscode-tlaplus/blob/master/resources/knowledgebase/tlc-config-files.md) and the [stable TLC worker implementation](https://github.com/tlaplus/tlaplus/blob/v1.7.4/tlatools/org.lamport.tlatools/src/tlc2/tool/Worker.java).

The bounded configurations check safety. `Spec` permits stuttering and has no fairness assumption, so `GameEventuallyEnds` fails even for an unconstrained tiny game. A bounded search also truncates play. Termination needs a separate fairness and liveness model, with the constraint's effect accounted for; see [Specifying Systems, §14.3.5](https://lamport.azurewebsites.net/tla/book.html). Both bounded configurations set `CHECK_DEADLOCK FALSE` because winning and full boards intentionally have no next move. `MoveAvailability` checks that unfinished boards still have a legal column.

## Tests

Run the board-operation checks:

```bash
java -Xmx1g -jar tla2tools.jar -workers 1 -config TestConnect4.cfg TestConnect4.tla
```

They cover empty boards, gravity and full columns, all four win directions, normalization, and a seven-move winning sequence.

With Python 3 installed, run the model checks and constraint controls together:

```bash
python3 tests/check_tlc.py ./tla2tools.jar
```

The suite checks the four-move opening model, exhausts a small game using the twenty-move configuration, checks reachability on a tiny board, and samples the twenty-move 6×7 model. Its expected failures verify that invariants still see a successor beyond the state constraint, that a primed guard changes deadlock behavior, and that stuttering defeats the eventual-termination property.

The [TLC check record](docs/TLC_CHECKS.md) gives the tool version, commands, and results, including the scope of the sampled twenty-move run.

## Other specifications

`Connect4Apalache.tla`, `Connect4Optimized.tla`, and their configurations are separate experimental variants. `Connect4Analysis.tla` and `StateSpaceAnalysis.tla` contain analysis helpers. The TLC checks above exercise `Connect4.tla` and `TestConnect4.tla`.

## References

- [TLC command-line options](https://docs.tlapl.us/using:tlc:start)
- [TLA+ language manual](https://lamport.azurewebsites.net/tla/book.html)
- [Apalache documentation](https://apalache-mc.org/docs/)
- [Connect 4 analysis by John Tromp](https://tromp.github.io/c4/c4.html)
