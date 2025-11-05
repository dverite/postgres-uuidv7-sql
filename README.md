# postgres-uuidv7-sql
Pure SQL functions to use UUIDs v7 in PostgreSQL.

The functions are packaged as an extension ("uuidv7-sql")
for convenience, but they may also be created individually
by sourcing all or parts of the [creation scripts](sql/).

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
Generate a UUID v7 value using the current time with millisecond precision
and 74 bits of randomness. With PostgreSQL version 18 or newer,
a [built-in function](https://www.postgresql.org/docs/18/functions-uuid.html) with the same name exists in `pg_catalog`,
coming first in the search path. You may prefix `uuidv7` with the schema
(for instance `public.uuidv7()`) to specifically use the version of
this extension, or just use the built-in function instead.

### `uuidv7(timestamptz) -> uuid`
Generate a UUID v7 value using the given time with millisecond precision
and 74 bits of randomness.

### `uuidv7_sub_ms() -> uuid`
Generate a UUID v7 value using the current time with sub-millisecond
precision (up to 0.25 µs), with 62 bits of randomness.

### `uuidv7_sub_ms(timestamptz) -> uuid`
Generate a UUID v7 value using the given time with sub-millisecond
precision (up to 0.25 µs), with 62 bits of randomness.

### `uuidv7_extract_timestamp(uuid) -> timestamptz`
Extract the timestamp with millisecond precision from the given UUID v7 value.

### `uuidv7_boundary(timestamptz) -> uuid`
Generate a non-random uuidv7 with the given timestamp (first 48 bits) and all random bits to 0. As the smallest possible uuidv7 for that timestamp, it may be used as a boundary for tables partitioned by ranges of UUID.

### `uuidv7_encrypt(input uuid, crypt_key bytea, [uuid_ver int]) -> uuid`
Transform a UUID-v7 value into an equivalent UUID-v4 or UUID-v8 (passing 4 or 8 in `uuid_ver`) that does not leak the timestamp. The bit fields `unix_ts_ms` + `rand_a` + 4 more bits (total: 64 bits) from the UUID-v7 value are encrypted  with an [XTEA cipher](https://en.wikipedia.org/wiki/XTEA). The 16-byte `crypt_key` parameter is the encryption key.

### `uuidv7_decrypt(input uuid, crypt_key bytea) -> uuid`
Decrypt a UUID (either v4 or v8) produced by `uuidv7_encrypt()` with the same `crypt_key`.
