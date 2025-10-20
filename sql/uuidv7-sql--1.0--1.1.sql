-- \echo Use "ALTER EXTENSION "uuidv7-sql" UPDATE TO '1.1'" to load this file. \quit

/*
 Transform a UUID-v7 value into an equivalent UUID-v4 or UUID-v8 (passing
 4 or 8 in "uuid_ver"), that does not reveal the timestamp.
 The fields unix_ts_ms + rand_a + 4 more bits (to reach 64 bits) are encrypted
 with an XTEA cipher. The 16-byte "crypt_key" parameter is the encryption key.
*/
CREATE FUNCTION uuidv7_encrypt(input uuid, crypt_key bytea, uuid_ver int default 4)
RETURNS uuid
SET bytea_output to 'hex'
AS $$
DECLARE
 key128 int8[4];
 uuid_parts int8;
 v0 int8;
 v1 int8;
 f_sum int8:=0;
 uuid_bits bit(128);
 r1 int8;
 r2 int8;
 rounds constant int:=32;
BEGIN
  IF octet_length(crypt_key)<>16 THEN
    raise exception 'Encryption key must be 16 bytes long';
  END IF;
  /* transfer encryption key into 4x32 bits */
  FOR i IN 1..4 LOOP
    key128[i] = right(substring(crypt_key from 1+(i-1)*4 for 4)::text,-1)::bit(32)::int8;
  END LOOP;

  uuid_bits = right(uuid_send(input)::text, -1)::bit(128); -- convert \x... to x...

  /* Extract and concatenate the UUID-v7 bit fields to encrypt:
     unix_t + 4 arbitrary bits from rand_b + rand_a */
  uuid_parts := (substring(uuid_bits from 1 for 48) ||
                 substring(uuid_bits from 93 for 4) ||
                 substring(uuid_bits from 53 for 12)
	         )::bit(64)::int8;

  /* encrypt this 64-bit number with an XTEA Feistel network */
  v0 := (uuid_parts>>32)&4294967295;
  v1 := uuid_parts&4294967295;

  FOR i in 1..rounds LOOP
    v0 := (v0 + ((
	   ((v1<<4)&4294967295 # (v1>>5))
	     + v1)&4294967295
		 #
		 (f_sum + key128[1+(f_sum&3)])&4294967295
		 ))&4294967295;
    f_sum := (f_sum + 2654435769) & 4294967295;
    v1 := (v1 + ((
	   ((v0<<4)&4294967295 # (v0>>5))
	     + v0)&4294967295
		#
		(f_sum + key128[1+((f_sum>>11)&3)])&4294967295
		))&4294967295;
  END LOOP;  /* encrypted value at the end = v0<<32 + v1 */

  /* Place the bit fields into their final positions */
  r1 := (v0::bit(32) || (v1>>16)::bit(16) || uuid_ver::bit(4) || (v1&4095)::bit(12))::bit(64)::int8;
  r2 := (substring(uuid_bits from 65 for 28) || substring(v1::bit(32) from 17 for 4)
    || substring(uuid_bits from 97 for 32))::bit(64)::int8;

  RETURN encode(int8send(r1) || int8send(r2), 'hex')::uuid;
END
$$ LANGUAGE plpgsql strict immutable;

COMMENT ON FUNCTION uuidv7_encrypt(uuid, bytea, int)
IS 'Encrypt a UUID-v7 into an equivalent UUID-v4 or UUID-v8 with an XTEA block cipher';



/*
 Transform a UUID encrypted by encrypt_uuidv7() back to the original
 UUID-v7 value.
 "crypt_key" must be the same 16-byte key that was used to encrypt.
*/
CREATE FUNCTION uuidv7_decrypt(input uuid, crypt_key bytea)
RETURNS uuid
SET bytea_output to 'hex'
AS $$
DECLARE
 key128 int8[4];
 uuid_parts int8;
 v0 int8;
 v1 int8;
 uuid_bits bit(128);
 r1 int8;
 r2 int8;
 rounds constant int:=32;
 f_sum int8 := (2654435769 * rounds)&4294967295;
BEGIN
  IF octet_length(crypt_key)<>16 THEN
    raise exception 'Encryption key must be 16 bytes long';
  END IF;
  /* transfer encryption key into 4x32 bits */
  FOR i IN 1..4 LOOP
    key128[i] = right(substring(crypt_key from 1+(i-1)*4 for 4)::text,-1)::bit(32)::int8;
  END LOOP;

  uuid_bits = right(uuid_send(input)::text, -1)::bit(128);

  /* Extract and concatenate the UUID-v4 bit fields to decrypt:
     random_a + 4 bits from random_c + random_b  */
  uuid_parts := (substring(uuid_bits from 1 for 48) ||
		 substring(uuid_bits from 93 for 4) ||
		 substring(uuid_bits from 53 for 12)
	         )::bit(64)::int8;

  /* decrypt this 64-bit number with an XTEA Feistel network */
  v0 := (uuid_parts>>32)&4294967295;
  v1 := uuid_parts&4294967295;
  FOR i in 1..32 LOOP
    v1 := (v1 - ((
	      ((v0<<4)&4294967295 # (v0>>5))
		  + v0)&4294967295
		  #
		  (f_sum + key128[1+((f_sum>>11)&3)])&4294967295
		  ))&4294967295;

    f_sum := (f_sum - 2654435769)& 4294967295;

    v0 := (v0 - ((
	     ((v1<<4)&4294967295 # (v1>>5))
	       + v1)&4294967295
		   #
		   (f_sum + key128[1+(f_sum&3)])&4294967295
		   ))&4294967295;
   END LOOP;

  /* Place the bit fields into their final positions, and set version to 7 */
  r1 := (v0::bit(32) || (v1>>16)::bit(16) || '0111'::bit(4) || (v1&4095)::bit(12))::bit(64)::int8;
  r2 := (substring(uuid_bits from 65 for 28) || substring(v1::bit(32) from 17 for 4)
    || substring(uuid_bits from 97 for 32))::bit(64)::int8;

  RETURN encode(int8send(r1) || int8send(r2), 'hex')::uuid;
END
$$ LANGUAGE plpgsql strict immutable;

COMMENT ON FUNCTION uuidv7_decrypt(uuid, bytea)
IS 'Decrypt a UUID produced by uuidv7_encrypt()'

