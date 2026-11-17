#!/usr/bin/env python3
"""
analyze_rules.py - check NSG rule files for common mistakes.

How to run (from the repo folder):
    python3 migration/analyze_rules.py network-policy        # the live rules
    python3 migration/analyze_rules.py migration/output      # converted NSX rules

What it looks for, inside each NSG and direction (Inbound / Outbound):

    ERROR   DUPLICATE PRIORITY  Two rules share a priority. Azure rejects this.
    ERROR   DUPLICATE           Same traffic, same action as an earlier rule. Delete one.
    ERROR   CONFLICT            Same traffic, opposite action. The earlier rule always
                                wins, so the later one never happens. Decide which is right.
    ERROR   SHADOWED            An earlier rule already covers all of this rule's traffic,
                                so this rule can never match.
    ERROR   TOO OPEN            Inbound: allows any source on any port.
                                Outbound: allows any destination on any port.
    WARNING OPEN SOURCE/DEST    Same, but limited to specific ports. Check it's intended.

It exits with code 1 if there are any errors, so the pipeline fails the PR.
Warnings are printed but don't fail anything.

"Covers" means: the earlier rule's source, destination, protocol and ports
each match everything the later rule matches ("*" matches anything).
"""
import glob
import json
import os
import sys

ANY = "*"


def side(rule, which):
    """Source or destination as one comparable value: an ASG name or an address."""
    asg = rule.get(f"{which}Asg", "")
    return f"asg:{asg}" if asg else rule.get(which, "") or ANY


def port_range(port):
    if port == ANY:
        return 0, 65535
    low, _, high = port.partition("-")
    return int(low), int(high or low)


def ports_cover(outer, inner):
    """True if every port in `inner` is inside some port in `outer`."""
    outer_ranges = [port_range(p) for p in outer]
    for p in inner:
        lo, hi = port_range(p)
        if not any(olo <= lo and hi <= ohi for olo, ohi in outer_ranges):
            return False
    return True


def covers(a, b):
    """Does rule `a` match all the traffic rule `b` matches?"""
    return (
        (side(a, "source") == ANY or side(a, "source") == side(b, "source"))
        and (side(a, "destination") == ANY or side(a, "destination") == side(b, "destination"))
        and (a["protocol"] == ANY or a["protocol"].lower() == b["protocol"].lower())
        and ports_cover(a["ports"], b["ports"])
    )


def same_traffic(a, b):
    return covers(a, b) and covers(b, a)


def analyze(policy):
    findings = []  # (level, kind, message)
    name = policy["nsgName"]
    for direction in ("Inbound", "Outbound"):
        rules = sorted((r for r in policy["rules"] if r["direction"] == direction),
                       key=lambda r: r["priority"])

        seen = {}
        for r in rules:
            if r["priority"] in seen:
                findings.append(("ERROR", "DUPLICATE PRIORITY",
                                 f"{name} {direction}: '{r['name']}' and '{seen[r['priority']]}' both use priority {r['priority']}."))
            seen[r["priority"]] = r["name"]

        for i, later in enumerate(rules):
            for earlier in rules[:i]:
                if not covers(earlier, later):
                    continue
                if same_traffic(earlier, later) and earlier["access"] == later["access"]:
                    kind, msg = "DUPLICATE", "does the same thing as"
                elif same_traffic(earlier, later):
                    kind, msg = "CONFLICT", f"({later['access']}) is the opposite of"
                else:
                    kind = "SHADOWED"
                    msg = f"({later['access']}) can never match, because it is fully covered by"
                findings.append(("ERROR", kind,
                                 f"{name} {direction}: '{later['name']}' (priority {later['priority']}) {msg} "
                                 f"'{earlier['name']}' ({earlier['access']}, priority {earlier['priority']})."))
                break  # report only the first rule that covers it

            if later["access"] != "Allow":
                continue
            # Inbound: who can reach us? Outbound: where can we go?
            far_end = "source" if direction == "Inbound" else "destination"
            if side(later, far_end) != ANY:
                continue
            if later["ports"] == [ANY]:
                findings.append(("ERROR", "TOO OPEN",
                                 f"{name} {direction}: '{later['name']}' allows any {far_end} on any port and protocol."))
            else:
                findings.append(("WARNING", "OPEN " + far_end.upper(),
                                 f"{name} {direction}: '{later['name']}' allows any {far_end} on port(s) "
                                 f"{', '.join(later['ports'])}. Is that intended?"))
    return findings


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 migration/analyze_rules.py <folder with NSG JSON files>")
        sys.exit(2)

    files = sorted(glob.glob(os.path.join(sys.argv[1], "*.json")))
    if not files:
        print(f"No JSON files found in {sys.argv[1]}")
        sys.exit(2)

    all_findings = []
    for path in files:
        with open(path) as f:
            policy = json.load(f)
        all_findings += analyze(policy)
        print(f"Checked {os.path.basename(path)}: {len(policy['rules'])} rules")

    errors = [f for f in all_findings if f[0] == "ERROR"]
    warnings = [f for f in all_findings if f[0] == "WARNING"]
    print()
    for level, kind, message in all_findings:
        print(f"{level:7} {kind:18} {message}")
    print()
    print(f"Result: {len(errors)} error(s), {len(warnings)} warning(s).")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
