SET ROLE nfttracker_owner;

DROP FUNCTION IF EXISTS nfttracker_backend.get_nft_instances_by_trx;
CREATE OR REPLACE FUNCTION nfttracker_backend.get_nft_instances_by_trx(
    "p_trx_id" TEXT,
    "p_count" INTEGER DEFAULT NULL,
    "p_last_id" NUMERIC DEFAULT NULL
)
RETURNS nfttracker_endpoints.nft_instance_with_type[]
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  IF p_trx_id !~ '^[0-9a-fA-F]{40}$' THEN
    RAISE EXCEPTION 'Invalid transaction hash: expected 40 hex characters, got: %', p_trx_id;
  END IF;

  RETURN COALESCE(ARRAY(
    SELECT ROW(
      i.id::TEXT,
      c.name,
      t.symbol,
      h.name,
      i.data,
      i.tags,
      i.soulbound,
      i.created_at,
      i.updated_at
    )::nfttracker_endpoints.nft_instance_with_type
    FROM nfttracker_app.instances i
    JOIN nfttracker_app.types t ON i.type_id = t.id
    JOIN hafd.accounts h ON i.holder = h.id
    JOIN hafd.accounts c ON t.creator = c.id
    JOIN hafd.operations o ON o.id = i.operation_id
    JOIN hafd.transactions tx
      ON tx.block_num = hafd.operation_id_to_block_num(o.id)
      AND tx.trx_in_block = o.trx_in_block
    WHERE tx.trx_hash = decode(p_trx_id, 'hex')
      AND (p_last_id IS NULL OR i.id > p_last_id)
    ORDER BY i.id
    LIMIT LEAST(p_count, 1000)
  ), ARRAY[]::nfttracker_endpoints.nft_instance_with_type[]);
END
$$;

RESET ROLE;
