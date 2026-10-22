SET ROLE nfttracker_owner;

/*
 * require_trx_hash_index() — fail fast while hafd.transactions has no trx_hash
 * index. Its PK (pk_hive_transactions) is dropped during HAF's massive sync,
 * even under the keep-monotonic policy that lets block processing run during
 * it, so a lookup by hash would seq-scan the table instead of answering.
 * On a HAF without hive.are_core_indexes_created() the PK exists only once
 * hive.is_instance_ready() holds.
 */
CREATE OR REPLACE FUNCTION nfttracker_backend.require_trx_hash_index()
RETURNS VOID
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  IF to_regprocedure('hive.are_core_indexes_created(text, text)') IS NOT NULL THEN
    IF NOT hive.are_core_indexes_created('hafd.transactions', 'pk_hive_transactions') THEN
      RAISE EXCEPTION 'HAF has not built its transaction hash index yet (massive sync in progress)'
        USING ERRCODE = '55000';
    END IF;
  ELSIF NOT hive.is_instance_ready() THEN
    RAISE EXCEPTION 'HAF instance is not ready (massive sync in progress)'
      USING ERRCODE = '55000';
  END IF;
END
$$;

RESET ROLE;
