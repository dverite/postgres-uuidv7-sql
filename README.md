# postgres-uuidv7-sql
Pure SQL functions to use UUIDs v7 in PostgreSQL.

The functions are packaged as an extension ("uuidv7-sql")
for convenience, but they may also be created individually
by sourcing all or parts of the SQL script:
`sql/uuidv7-sql--1.0.sql`

## Extension installation
The Makefile uses the [PGXS infrastructure](https://www.postgresql.org/docs/current/static/extend-pgxs.html)

To make the extension available to a PostgreSQL server:

	$ [sudo] make install

The same, but targeting a specific PostgreSQL installation:

    $ [sudo] make PG_CONFIG=/path/to/pg_config install

To activate the extension in the target databases:

    CREATE EXTENSION "uuidv7-sql";

## Functions

### `uuidv7() -> uuid`
Generate an UUID v7 value with millisecond precision and 74 bits of randomness.

### `uuidv7_sub_ms() -> uuid`
Generate an UUID v7 value with sub-millisecond precision (up to 0.25 µs), with 62 bits of randomness.

### `uuidv7_extract_timestamp(uuid) -> timestamptz`
Extract the timestamp with millisecond precision from the given UUID v7 value.

### `uuidv7_boundary(timestamptz) -> uuid`
Generate a non-random uuidv7 with the given timestamp (first 48 bits) and all random bits to 0. As the smallest possible uuidv7 for that timestamp, it may be used as a boundary for partitions.
