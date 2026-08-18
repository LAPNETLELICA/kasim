# Threat Model

## Student uses a search engine not in the lecturer's whitelist
- **Threat**: Student attempts to access unauthorized search engines during exam lockdown.
- **Impact**: Potential cheating by accessing unapproved information sources.
- **Mitigation**: Only lecturer-selected domains in allowedHosts[]; all others are dropped at OS kernel level via nftables/WFP rules. The agent applies DROP policy by default, with explicit ACCEPT rules only for whitelisted hosts. Always-allowed Firebase endpoints ensure agent functionality but do not permit general internet access.