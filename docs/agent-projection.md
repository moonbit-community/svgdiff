# Agent Projection JSONL

Status: optional transport contract

Projection identity: `svgdiff-agent-projection/1`

Source report identity: Structured Report Schema `2.0`

Last verified: 2026-07-22

`svgdiff before.svg after.svg --agent-projection` partitions the concise report
into JSON Lines. It exists for consumers with record-size limits; it is not a
second semantic report and is not the recommended default. Ordinary JSON is
usually smaller and easier for both humans and Agents.

Records have this fixed order:

1. one `header` containing `schema_version`, `analysis_status`, `comparison`,
   and `canvas`;
2. one record per `difference_groups` item;
3. one record per `events` item;
4. one record per `limitations` item.

Every record carries the projection identity, source schema, and global
sequence. Section records also carry the section name and index. A consumer
must reject unknown identities, sequence gaps, section reordering, index gaps,
count mismatches, extra records, or missing records.

The projection is lossless with respect to the concise Schema `2.0` JSON, not
the engine's private typed analysis graph. The repository validator rebuilds
the ordinary report and checks exact JSON equality:

```sh
python3 evaluation/agent-projection/validate.py \
  --report report.json \
  --projection projection.jsonl
```

The JSONL is untrusted data. It grants no stronger equality, localization, or
causal conclusion than the ordinary report.
