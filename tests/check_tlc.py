#!/usr/bin/env python3
"""Run bounded safety checks and controls for TLC constraint semantics."""

import argparse
import pathlib
import re
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
SAFETY = """INVARIANTS
    TypeInvariant
    NoDuplicateStates
    PieceCountConsistency
    TurnConsistency
    GravityInvariant
    TerminalConsistency
    MoveAvailability
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("jar", type=pathlib.Path, help="path to tla2tools.jar")
    args = parser.parse_args()
    jar = args.jar.resolve()
    if not jar.is_file():
        parser.error(f"TLC jar not found: {jar}")

    with tempfile.TemporaryDirectory(prefix="connect4-tlc-") as directory:
        scratch = pathlib.Path(directory)

        def run(name, module, config, *, text=None, extra=(), expected=0, contains=()):
            if text is not None:
                config = scratch / f"{name}.cfg"
                config.write_text(text)
            command = ["java", "-Xmx1g", "-jar", str(jar), "-workers", "1",
                       "-metadir", str(scratch / name), "-config", str(config),
                       *extra, module]
            result = subprocess.run(command, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=300)
            if result.returncode != expected or any(s not in result.stdout for s in contains):
                raise AssertionError(f"{name}: exit {result.returncode}, expected {expected}\n"
                                     f"{result.stdout}")
            stats = re.findall(r"^.*(?:states generated|distinct states found|traces generated).*$",
                               result.stdout, re.MULTILINE)
            print(f"PASS {name}" + (f": {stats[-1]}" if stats else ""), flush=True)
            return result.stdout

        success = ("Model checking completed. No error has been found.",)
        run("operators", "TestConnect4.tla", "TestConnect4.cfg", contains=success)
        run("opening-four", "Connect4.tla", "Connect4.cfg", contains=success)

        boundary = """INIT Init
NEXT Next
CONSTANTS
    ROWS = 1
    COLS = 1
    PLAYERS = {1, 2}
    MAX_MOVES = 0
CONSTRAINT MoveLimit
CHECK_DEADLOCK TRUE
"""
        run("cutoff", "Connect4.tla", None, text=boundary + SAFETY,
            contains=success + ("2 states generated, 1 distinct states found",))
        # TLC checks the one-move successor even though it fails MoveLimit.
        run("cutoff-invariant", "TestConnect4.tla", None,
            text=boundary + "INVARIANT WithinMoveLimit\n", expected=12,
            contains=("Invariant WithinMoveLimit is violated.", "moveCount = 1"))
        # A primed guard prevents successor generation and causes a real deadlock.
        run("primed-guard", "TestConnect4.tla", None,
            text=boundary.replace("NEXT Next", "NEXT GuardedNext"), expected=11,
            contains=("Deadlock reached.", "moveCount = 0"))
        # No fairness in Spec: even an unconstrained game can stutter forever.
        run("termination-control", "Connect4.tla", None,
            text=boundary.replace("CONSTRAINT MoveLimit\n", "")
                         .replace("CHECK_DEADLOCK TRUE", "CHECK_DEADLOCK FALSE")
                         + "PROPERTY GameEventuallyEnds\n", expected=13,
            contains=("Temporal properties were violated.", "Stuttering"))

        # Exhaust the small game, including terminal states, with the 20-move config.
        bounded20 = (ROOT / "Connect4Bounded20.cfg").read_text()
        run("small-game-twenty", "Connect4.tla", None,
            text=bounded20.replace("ROWS = 6", "ROWS = 4").replace("COLS = 7", "COLS = 2"),
            contains=success)
        run("tiny-reachability", "Connect4.tla", None,
            text=bounded20.replace("ROWS = 6", "ROWS = 1").replace("COLS = 7", "COLS = 2")
                         + "INVARIANT BoardReachability\n", contains=success)

        traces = scratch / "sample"
        output = run("twenty-move-simulation", "Connect4.tla", "Connect4Bounded20.cfg",
                     extra=("-simulate", f"num=20,file={traces}", "-depth", "22", "-seed", "1"),
                     contains=("Simulation", "seed 1"))
        counts = [int(n) for trace in scratch.glob("sample*")
                  for n in re.findall(r"moveCount = (\d+)", trace.read_text())]
        if not counts or not 20 <= max(counts) <= 21:
            raise AssertionError(f"Simulation did not respect/reach the 20-move bound.\n{output}")
        print(f"PASS simulation reaches move {max(counts)} (sampled, not exhaustive)")


if __name__ == "__main__":
    main()
