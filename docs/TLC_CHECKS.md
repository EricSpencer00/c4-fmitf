# TLC check record — October 5, 2026

The checks use the stable [TLA+ tools v1.7.4 release](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4): TLC 2.19, revision `5a47802`, Java 23.0.2, one worker, and a 1 GiB Java heap. The downloaded `tla2tools.jar` has SHA-1 `bee4a54f3ee3d4afc347c3240ec2d9e93b075104`, matching the release's published checksum.

From the repository root:

```bash
python3 tests/check_tlc.py ./tla2tools.jar
```

The suite creates temporary configurations and metadata directories. Each model check must finish, empty its queue, and report success. The negative controls must return the expected TLC violation code and name the expected failure.

| Check | Configuration or property | Result |
|---|---|---|
| Board operations | `TestConnect4.cfg`, `AllTests` | Pass; 2 generated, 1 distinct state |
| Opening model | `Connect4.cfg`, 6×7, `MAX_MOVES = 4` | Pass; 19,314 generated, 2,759 distinct states |
| Constraint cutoff | 1×1, `MAX_MOVES = 0`, deadlock checking enabled | Pass; 2 generated, 1 distinct state |
| Invariant at cutoff | Same constraint, `WithinMoveLimit` invariant | Expected safety violation (exit 12) at `moveCount = 1` |
| Primed guard | Same empty board, `Next /\ MoveLimit'` | Expected deadlock (exit 11) at `moveCount = 0` |
| Termination control | Unconstrained 1×1 game, `GameEventuallyEnds` | Expected temporal violation (exit 13), ending in stuttering |
| Complete small game | Twenty-move config with 4×2 board | Pass; 231 generated, 228 distinct states, including terminal positions |
| Tiny reachability | Twenty-move config with 1×2 board, `BoardReachability` | Pass; 5 generated, 5 distinct states |
| Twenty-move sample | `Connect4Bounded20.cfg`, 6×7, 20 traces, depth 22, seed 1 | Pass; sampled play reaches move 21, the invariant-checked successor beyond the bound |

The standalone commands used by the README are:

```bash
java -Xmx1g -jar tla2tools.jar -workers 1 -config Connect4.cfg Connect4.tla
java -Xmx1g -jar tla2tools.jar -workers 1 -config TestConnect4.cfg TestConnect4.tla
java -Xmx1g -jar tla2tools.jar -workers 1 -config Connect4Bounded20.cfg -simulate num=20 -depth 22 -seed 1 Connect4.tla
```

The four-move model and small-board models were exhausted. The 6×7 twenty-move configuration was checked by simulation; its exhaustive search remains a larger computation. The original bound of ten moves was reduced to four for the default reproducible check. The twenty-move configuration keeps a separate deeper-search example.

## Audit findings

The original README supplied `-constraint "moveCount <= 20"`, while `Connect4.cfg` embedded TLA+ expressions directly under `CONSTRAINT` and `VIEW`. The corrected configurations reference `MoveLimit`, a named state predicate, and keep the complete state for fingerprinting.

`Connect4.tla` imported an unavailable `Apalache` module, compared function-valued boards with integer `<=`, and referred forward to a sequence helper with an undeclared recursive definition. The TLC model now uses standard modules, a row-major lexicographic comparison, and a declared recursive replay helper. Reachability enumerates a finite set of sequences and is checked only on a tiny board.

The old configuration also requested `GameEventuallyEnds` from a specification without fairness. The stuttering control demonstrates why that property fails. Bounded configurations now check safety, including a state invariant for winner and terminal-state consistency. Winning and full boards deliberately end play, so these configurations disable deadlock reporting while checking move availability in unfinished games.

The old test command named a missing `TestConnect4.cfg`. The test module now exercises the TLC core and has an explicit initialization, stuttering step, and invariant configuration.

The old README's state-space and memory ratios were estimates presented as results. The implementation stores both the live board and a history of normalized boards. The README now describes that representation and the measured check scopes.
