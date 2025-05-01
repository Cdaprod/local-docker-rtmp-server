# Automation CLI Index

### Run the CLI via:

```bash
ts-node lib/automation/index.ts generate-clips --videoId=<ID> --segments='[{"start":0,"end":5}]'
ts-node lib/automation/index.ts enrich-metadata --clipId=<ID>
ts-node lib/automation/index.ts export-csv --out=./blackbox.csv
```

### Troubleshooting Automation:

- Make sure you have sanityClient.ts exporting a configured Sanity client, and that your other modules (clipGenerator.ts, etc.) export the named functions.

