SET ROLE nfttracker_owner;

DROP FUNCTION IF EXISTS nfttracker_backend.get_nft_instances;
CREATE OR REPLACE FUNCTION nfttracker_backend.get_nft_instances(
    "creator" TEXT,
    "symbol" TEXT,
    "tags" TEXT,
    "p_count" INTEGER DEFAULT NULL,
    "p_last_id" NUMERIC DEFAULT NULL
)
RETURNS nfttracker_endpoints.nft_instance[]
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
  _creator TEXT := creator;
  _symbol TEXT := symbol;
  _tags TEXT := NULLIF(tags, '');
BEGIN
  RETURN COALESCE(ARRAY(
    SELECT ROW(
      i.id::TEXT,
      h.name,
      i.data,
      i.tags,
      i.soulbound,
      i.created_at,
      i.updated_at
    )::nfttracker_endpoints.nft_instance
    FROM nfttracker_app.instances AS i
    INNER JOIN nfttracker_app.types AS t ON i.type_id = t.id
    LEFT JOIN hafd.accounts AS h ON i.holder = h.id
    WHERE t.symbol = _symbol
      AND t.creator = (SELECT id FROM hafd.accounts WHERE name = _creator)
      AND (_tags IS NULL OR i.tags::TEXT[] @> ANY(
        SELECT STRING_TO_ARRAY(t, ',')
        FROM UNNEST(STRING_TO_ARRAY(_tags, '|')) AS t
      ))
      AND (p_last_id IS NULL OR i.id > p_last_id)
    ORDER BY i.id
    LIMIT LEAST(p_count, 1000)
  ), ARRAY[]::nfttracker_endpoints.nft_instance[]);
END
$$;

RESET ROLE;
