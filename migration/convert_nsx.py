#!/usr/bin/env python3
"""
convert_nsx.py - turn an NSX firewall export (CSV) into NSG rule files (JSON).

How to run (from the repo folder):
    python3 migration/convert_nsx.py migration/nsx-export-sample.csv

What it writes into migration/output/:
    - one JSON file per NSG, in the same format as network-policy/
    - translation-report.md, listing every NSX rule and what happened to it

The rules it follows, in plain words:
    1. Disabled NSX rules are skipped (and listed in the report).
    2. Rules that use a website name (FQDN:...) can't be an NSG rule.
       They are listed as "needs Azure Firewall".
    3. Rules that use a user group (ADGROUP:...) can't be an NSG rule.
       NSGs only understand IP addresses, not people. They need a human decision.
    4. If the destination is an NSX group (SG-...), the rule becomes an
       INBOUND rule on that group's NSG.
    5. Otherwise, if the source is an NSX group, it becomes an OUTBOUND rule
       on the source group's NSG.
    6. ASGs only work inside one VNet. If the source and destination groups
       are in different VNets, the source subnet range is used instead.
    7. ALLOW -> Allow. DROP -> Deny. REJECT -> Deny, with a warning, because
       NSX Reject tells the sender "no" while an NSG Deny stays silent.
    8. Priorities keep the NSX order: Infrastructure rules from 1100,
       Application rules from 2000, in steps of 10. Every NSG also gets the
       standard load balancer allow (1000) and deny-all inbound (4000).
"""
import csv
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(HERE, "output")

START_PRIORITY = {"Infrastructure": 1100, "Application": 2000}
STEP = 10


def load_group_map():
    with open(os.path.join(HERE, "group-map.json")) as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith("_")}


def parse_service(service):
    """'TCP/443' -> ('Tcp', ['443']).  'ANY' -> ('*', ['*'])."""
    service = service.strip().upper()
    if service in ("ANY", "*"):
        return "*", ["*"]
    proto, _, port = service.partition("/")
    proto = {"TCP": "Tcp", "UDP": "Udp", "ICMP": "Icmp"}.get(proto, proto.title())
    return proto, [port or "*"]


def safe_name(rule_id, name):
    """NSG rule names: letters, numbers, dash, underscore, dot."""
    clean = re.sub(r"[^A-Za-z0-9_.-]", "-", name)
    return f"NSX{rule_id}-{clean}"[:80]


def platform_rules():
    """The two rules every NSG in this lab has (same as network-policy/)."""
    return [
        {
            "name": "Allow-AzureLoadBalancer-Inbound", "priority": 1000,
            "direction": "Inbound", "access": "Allow", "protocol": "*",
            "source": "AzureLoadBalancer", "sourceAsg": "",
            "destination": "*", "destinationAsg": "", "ports": ["*"],
            "description": "Platform health probes. Needed because of the explicit deny at 4000.",
        },
        {
            "name": "Deny-All-Inbound", "priority": 4000,
            "direction": "Inbound", "access": "Deny", "protocol": "*",
            "source": "*", "sourceAsg": "",
            "destination": "*", "destinationAsg": "", "ports": ["*"],
            "description": "Overrides the default AllowVnetInBound (65000).",
        },
    ]


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 migration/convert_nsx.py <nsx-export.csv>")
        sys.exit(2)

    groups = load_group_map()
    nsgs = {}            # nsg name -> list of rules
    counters = {}        # (nsg, direction, category) -> next priority
    report = []          # rows for the report

    def add_report(row, status, detail):
        report.append((row["rule_id"], row["name"], status, detail))

    with open(sys.argv[1], newline="") as f:
        rows = sorted(csv.DictReader(f), key=lambda r: int(r["rule_id"]))

    for row in rows:
        src = row["source"].strip()
        dst = row["destination"].strip()
        action = row["action"].strip().upper()

        if row["state"].strip().lower() != "enabled":
            add_report(row, "SKIPPED", "Disabled in NSX. Not migrated.")
            continue
        if src.upper().startswith("FQDN:") or dst.upper().startswith("FQDN:"):
            add_report(row, "NEEDS AZURE FIREWALL",
                       "Uses a website name. NSGs only understand IP addresses. Becomes an Azure Firewall application rule (Phase 7).")
            continue
        if src.upper().startswith("ADGROUP:") or dst.upper().startswith("ADGROUP:"):
            add_report(row, "NEEDS HUMAN DECISION",
                       "Uses a user group. NSGs can't match users. Options: allow the users' network range, or use an identity-aware service.")
            continue

        protocol, ports = parse_service(row["service"])
        access = {"ALLOW": "Allow", "DROP": "Deny", "REJECT": "Deny"}.get(action)
        if access is None:
            add_report(row, "NEEDS HUMAN DECISION", f"Unknown NSX action '{action}'.")
            continue

        rule = {"protocol": protocol, "ports": ports, "access": access,
                "source": "", "sourceAsg": "", "destination": "", "destinationAsg": ""}

        if dst in groups and groups[dst]["nsg"]:
            # Inbound on the destination's NSG.
            nsg, direction = groups[dst]["nsg"], "Inbound"
            rule["destinationAsg"] = groups[dst]["asg"]
            if src in groups:
                same_vnet = groups[src]["vnet"] == groups[dst]["vnet"]
                if same_vnet and groups[src]["asg"]:
                    rule["sourceAsg"] = groups[src]["asg"]
                else:
                    rule["source"] = groups[src]["subnet"]
            else:
                rule["source"] = "*" if src.upper() == "ANY" else src
        elif src in groups and groups[src]["nsg"]:
            # Outbound on the source's NSG.
            nsg, direction = groups[src]["nsg"], "Outbound"
            rule["sourceAsg"] = groups[src]["asg"]
            if dst in groups:
                rule["destination"] = groups[dst]["subnet"]
            else:
                rule["destination"] = "*" if dst.upper() == "ANY" else dst
        else:
            add_report(row, "NEEDS HUMAN DECISION",
                       "Neither side is a group with an NSG in group-map.json, so there's no NSG to put it on.")
            continue

        category = row["category"].strip() if row["category"].strip() in START_PRIORITY else "Application"
        key = (nsg, direction, category)
        priority = counters.get(key, START_PRIORITY[category])
        counters[key] = priority + STEP

        rule.update({
            "name": safe_name(row["rule_id"], row["name"]),
            "priority": priority,
            "direction": direction,
            "description": f"From NSX rule {row['rule_id']} ({row['name']}).",
        })
        nsgs.setdefault(nsg, []).append(rule)

        detail = f"{direction} rule on {nsg}, priority {priority}."
        if action == "REJECT":
            add_report(row, "TRANSLATED (BEHAVIOR CHANGE)",
                       detail + " NSX Reject replies 'no'; an NSG Deny drops silently, so apps may wait for a timeout instead of failing fast.")
        else:
            add_report(row, "TRANSLATED", detail)

    # Write one JSON file per NSG.
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    key_order = ["name", "priority", "direction", "access", "protocol", "source",
                 "sourceAsg", "destination", "destinationAsg", "ports", "description"]
    for nsg, rules in sorted(nsgs.items()):
        all_rules = platform_rules() + rules
        all_rules.sort(key=lambda r: (r["direction"], r["priority"]))
        policy = {
            "nsgName": nsg,
            "description": f"Translated from NSX ({nsg})",
            "rules": [{k: r[k] for k in key_order} for r in all_rules],
        }
        with open(os.path.join(OUTPUT_DIR, f"{nsg}.json"), "w") as f:
            json.dump(policy, f, indent=2)
            f.write("\n")

    # Write the report.
    lines = ["# NSX translation report", "",
             f"Source file: `{os.path.basename(sys.argv[1])}`", "",
             "| NSX rule | Name | Result | Details |", "| --- | --- | --- | --- |"]
    lines += [f"| {rid} | {name} | {status} | {detail} |" for rid, name, status, detail in report]
    counts = {}
    for _, _, status, _ in report:
        counts[status] = counts.get(status, 0) + 1
    lines += ["", "## Totals", ""] + [f"- **{s}:** {n}" for s, n in sorted(counts.items())]
    with open(os.path.join(OUTPUT_DIR, "translation-report.md"), "w") as f:
        f.write("\n".join(lines) + "\n")

    # Print a short summary on screen.
    print(f"Read {len(rows)} NSX rules. Wrote {len(nsgs)} NSG files to migration/output/.")
    for status, n in sorted(counts.items()):
        print(f"  {status}: {n}")
    print("Full details: migration/output/translation-report.md")
    print("Next step: python3 migration/analyze_rules.py migration/output")


if __name__ == "__main__":
    main()
