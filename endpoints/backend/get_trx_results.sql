SET ROLE nfttracker_owner;

DROP FUNCTION IF EXISTS nfttracker_backend.get_trx_results;
CREATE OR REPLACE FUNCTION nfttracker_backend.get_trx_results(
    "p_trx_id" TEXT,
    "p_count" INTEGER DEFAULT NULL,
    "p_last_id" BIGINT DEFAULT NULL
)
RETURNS nfttracker_endpoints.trx_result[]
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  IF p_trx_id !~ '^[0-9a-fA-F]{40}$' THEN
    RAISE EXCEPTION 'Invalid transaction hash: expected 40 hex characters, got: %', p_trx_id;
  END IF;

  RETURN COALESCE(ARRAY(
    SELECT ROW(
      r.id,
      r.op_pos,
      r.subsequent_no,
      r.action,
      r.symbol,
      r.account,
      r.success,
      r.error_message,
      r.created_at
    )::nfttracker_endpoints.trx_result
    FROM nfttracker_app.operation_results r
    JOIN hafd.operations o ON o.id = r.operation_id
    JOIN hafd.transactions tx
      ON tx.block_num = hafd.operation_id_to_block_num(o.id)
      AND tx.trx_in_block = o.trx_in_block
    WHERE tx.trx_hash = decode(p_trx_id, 'hex')
      AND (p_last_id IS NULL OR r.id > p_last_id)
    ORDER BY r.id
    LIMIT LEAST(p_count, 1000)
  ), ARRAY[]::nfttracker_endpoints.trx_result[]);
END
$$;

RESET ROLE;
