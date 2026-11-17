# NSX translation report

Source file: `nsx-export-reviewed.csv`

| NSX rule | Name | Result | Details |
| --- | --- | --- | --- |
| 1001 | web-https-in | TRANSLATED | Inbound rule on nsg-lz-spoke1-web, priority 2000. |
| 1002 | web-to-app | TRANSLATED | Inbound rule on nsg-lz-spoke1-app, priority 2000. |
| 1003 | app-to-db | TRANSLATED | Inbound rule on nsg-lz-spoke2-data, priority 2000. |
| 1005 | web-to-db-block | TRANSLATED | Inbound rule on nsg-lz-spoke2-data, priority 2010. |
| 1006 | mgmt-rdp-app | TRANSLATED | Inbound rule on nsg-lz-spoke1-app, priority 1100. |
| 1007 | app-https-out | TRANSLATED | Outbound rule on nsg-lz-spoke1-app, priority 2000. |
| 1009 | app-smtp-block | TRANSLATED | Outbound rule on nsg-lz-spoke1-app, priority 2010. |
| 1010 | web-updates | NEEDS AZURE FIREWALL | Uses a website name. NSGs only understand IP addresses. Becomes an Azure Firewall application rule (Phase 7). |
| 1011 | hr-portal | NEEDS HUMAN DECISION | Uses a user group. NSGs can't match users. Options: allow the users' network range, or use an identity-aware service. |
| 1012 | legacy-ftp | TRANSLATED (BEHAVIOR CHANGE) | Outbound rule on nsg-lz-spoke1-app, priority 2020. NSX Reject replies 'no'; an NSG Deny drops silently, so apps may wait for a timeout instead of failing fast. |
| 1013 | old-test-rule | SKIPPED | Disabled in NSX. Not migrated. |

## Totals

- **NEEDS AZURE FIREWALL:** 1
- **NEEDS HUMAN DECISION:** 1
- **SKIPPED:** 1
- **TRANSLATED:** 7
- **TRANSLATED (BEHAVIOR CHANGE):** 1
