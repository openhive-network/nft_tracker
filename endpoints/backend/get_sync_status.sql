SET ROLE nfttracker_owner;

/*
 * get_sync_status() — the last processed block as {last_block_num, last_block_time},
 * for the /sync-status endpoint (the HAF-wide uniform health/freshness API).
 * The timestamp lets consumers compute staleness with a single call
 * (age = now() - last_block_time) instead of needing a second head-block reference.
 *
 * The context name is hardcoded to 'nfttracker_app', matching db/schema.sql which
 * hardcodes it in hive.app_create_context() (this repo does not schema-inject its
 * SQL sources). LEFT JOIN so the pre-sync case (no processed block yet) still
 * yields an object with a null time rather than an error.
 */
DROP FUNCTION IF EXISTS nfttracker_backend.get_sync_status;
CREATE OR REPLACE FUNCTION nfttracker_backend.get_sync_status()
RETURNS JSON
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  -- Fail fast during HAF massive sync: hafd.blocks' PK is dropped for the
  -- duration (hive.disable_indexes_of_irreversible), so the join below
  -- would seq-scan the largest table in the database. Health-check agents
  -- gate on is_instance_ready() before calling APIs; this guard protects
  -- any caller that does not (e.g. a raw haproxy httpchk) by erroring in
  -- milliseconds instead of stalling.
  IF NOT hive.is_instance_ready() THEN
    RAISE EXCEPTION 'HAF instance is not ready (massive sync in progress)'
      USING ERRCODE = '55000';
  END IF;

  RETURN (
    SELECT json_build_object(
      'last_block_num', c.current_block_num,
      'last_block_time', to_char(b.created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
    )
    FROM hafd.contexts c
    LEFT JOIN hafd.blocks b ON b.num = c.current_block_num
    WHERE c.name = 'nfttracker_app'
  );
END
$$;

RESET ROLE;
