/* See the UUID Version 7 specification at
   https://www.rfc-editor.org/rfc/rfc9562#name-uuid-version-7 */


/* Main function to generate a uuidv7 value with millisecond precision */
CREATE FUNCTION uuidv7(timestamptz DEFAULT clock_timestamp()) RETURNS uuid
AS $$
  -- Replace the first 48 bits of a uuidv4 with the current
  -- number of milliseconds since 1970-01-01 UTC
  -- and set the "ver" field to 7 by setting additional bits
  select encode(
    set_bit(
      set_bit(
        overlay(uuid_send(gen_random_uuid()) placing
	  substring(int8send((extract(epoch from $1)*1000)::bigint) from 3)
	  from 1 for 6),
	52, 1),
      53, 1), 'hex')::uuid;
$$ LANGUAGE sql volatile parallel safe;

COMMENT ON FUNCTION uuidv7(timestamptz) IS
'Generate a uuid-v7 value with a 48-bit timestamp (millisecond precision) and 74 bits of randomness';


/* Version with the "rand_a" field containing sub-milliseconds (method 3 of the spec)
   clock_timestamp() is hoped to provide enough precision and consecutive
   calls to not happen fast enough to output the same values in that field.
   The uuid is the concatenation of:
   - 6 bytes with the current Unix timestamp (number of milliseconds since 1970-01-01 UTC)
   - 2 bytes with
      - 4 bits for the "ver" field
      - 12 bits for the fractional part after the milliseconds
   - 8 bytes of randomness from the second half of a uuidv4
 */
CREATE FUNCTION uuidv7_sub_ms(timestamptz DEFAULT clock_timestamp()) RETURNS uuid
AS $$
 select encode(
   substring(int8send(floor(t_ms)::int8) from 3) ||
   int2send((7<<12)::int2 | ((t_ms-floor(t_ms))*4096)::int2) ||
   substring(uuid_send(gen_random_uuid()) from 9 for 8)
  , 'hex')::uuid
  from (select extract(epoch from $1)*1000 as t_ms) s
$$ LANGUAGE sql volatile parallel safe;

COMMENT ON FUNCTION uuidv7_sub_ms(timestamptz) IS
'Generate a uuid-v7 value with a 60-bit timestamp (sub-millisecond precision) and 62 bits of randomness';

/* Extract the timestamp in the first 6 bytes of the uuidv7 value.
   Use the fact that 'xHHHHH' (where HHHHH are hexadecimal numbers)
   can be cast to bit(N) and then to int8.
 */
CREATE FUNCTION uuidv7_extract_timestamp(uuid) RETURNS timestamptz
AS $$
 select to_timestamp(
   right(substring(uuid_send($1) from 1 for 6)::text, -1)::bit(48)::int8 -- milliseconds
    /1000.0);
$$ LANGUAGE sql immutable strict parallel safe;

COMMENT ON FUNCTION uuidv7_extract_timestamp(uuid) IS
'Return the timestamp stored in the first 48 bits of the UUID v7 value';


CREATE FUNCTION uuidv7_boundary(timestamptz) RETURNS uuid
AS $$
  /* uuid fields: version=0b0111, variant=0b10 */
  select encode(
    overlay('\x00000000000070008000000000000000'::bytea
      placing substring(int8send(floor(extract(epoch from $1) * 1000)::bigint) from 3)
        from 1 for 6),
    'hex')::uuid;
$$ LANGUAGE sql stable strict parallel safe;

COMMENT ON FUNCTION uuidv7_boundary(timestamptz) IS
'Generate a non-random uuidv7 with the given timestamp (first 48 bits) and all random bits to 0. As the smallest possible uuidv7 for that timestamp, it may be used as a boundary for partitions.';
