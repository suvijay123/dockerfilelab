"""Checks which modern Python features work in THIS container's Python."""
import socket
import sys

GREEN, RED, BOLD, RESET = "\033[92m", "\033[91m", "\033[1m", "\033[0m"

FEATURES = [
    ("f-strings",          "3.6",  "x = f'{1 + 1}'"),
    ("walrus operator :=", "3.8",  "(n := 10)"),
    ("match statement",    "3.10", "match 1:\n    case 1:\n        pass"),
    ("exception groups",   "3.11", "try:\n    pass\nexcept* ValueError:\n    pass"),
    ("type aliases",       "3.12", "type Point = tuple[float, float]"),
]

version = sys.version.split()[0]
print(f"\n{BOLD}  Python Time Machine{RESET}")
print(f"  Container {socket.gethostname()} is running Python {BOLD}{version}{RESET}\n")

passed = 0
for name, since, code in FEATURES:
    try:
        compile(code, "<feature>", "exec")
        print(f"  {GREEN}[ OK ]{RESET}  {name:<20} (needs {since}+)")
        passed += 1
    except SyntaxError:
        print(f"  {RED}[FAIL]{RESET}  {name:<20} (needs {since}+)")

colour = GREEN if passed == len(FEATURES) else RED
print(f"\n  {colour}{BOLD}{passed}/{len(FEATURES)} features work here.{RESET}")
if passed < len(FEATURES):
    print("  Code written on a newer laptop would CRASH on this server!")
else:
    print("  Pin this version in your Dockerfile and it works the same everywhere.")
print()
