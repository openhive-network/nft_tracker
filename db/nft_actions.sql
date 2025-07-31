SET ROLE nfttracker_owner;

CREATE OR REPLACE FUNCTION nfttracker_app.register(
  IN _block_num INT,
  IN _account hive.account_name_type,
  IN _json JSONB
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
BEGIN
  INSERT INTO nfttracker_app.types(
    creator,
    owner,
    symbol,
    name,
    max_count,
    created_at,
    updated_at
  )
  SELECT
    a.id,
    a.id,
    j.symbol,
    j.name,
    j.max_count,
    b.created_at,
    b.created_at
  FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
  JOIN hafd.blocks AS b ON b.num = _block_num
  JOIN hafd.accounts AS a ON a.name = j.owner;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.modify(
  IN _block_num INT,
  IN _account hive.account_name_type,
  IN _json JSONB
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
DECLARE
  _count BIGINT;
BEGIN
  WITH update_type AS (
    UPDATE nfttracker_app.types AS t
    SET
      name = j.name,
      owner = a.id,
      max_count = j.max_count,
      updated_at = b.created_at
    FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
    JOIN hafd.blocks AS b ON b.num = _block_num
    JOIN hafd.accounts AS a ON a.name = j.owner
    WHERE t.symbol = j.symbol
    RETURNING t.id
  ),
  issuers AS (
    SELECT j->>0 AS issuer FROM jsonb_array_elements(_json->'issuers') AS j
  ),
  insert_issuers AS (
    INSERT INTO nfttracker_app.authorized_issuers (type_id, account_id)
    SELECT t.id, a.id
    FROM update_type AS t
    JOIN hafd.accounts AS a ON a.name = ANY(SELECT issuer FROM issuers)
    ON CONFLICT (type_id, account_id) DO NOTHING
    RETURNING 1
  ),
  delete_issuers AS (
    DELETE FROM nfttracker_app.authorized_issuers AS ai
    WHERE ai.type_id IN (SELECT id FROM update_type) AND ai.account_id NOT IN (
      SELECT a.id
      FROM issuers AS j
      JOIN hafd.accounts AS a ON a.name = j.issuer
    )
    RETURNING 1
  )
  SELECT COUNT(*) INTO _count FROM (
    SELECT * FROM insert_issuers
    UNION ALL
    SELECT * FROM delete_issuers
  ) AS y;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.issue(
  IN _block_num INT,
  IN _account hive.account_name_type,
  IN _json JSONB
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
BEGIN
  INSERT INTO nfttracker_app.instances (
    type_id,
    holder,
    data,
    tags,
    soulbound,
    created_at,
    updated_at
  )
  SELECT
    t.id,
    a.id,
    j.data,
    j.tags,
    j.soulbound,
    b.created_at,
    b.created_at
  FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, data jsonb, tags nfttracker_app.tags, soulbound boolean, holder hive.account_name_type)
  JOIN nfttracker_app.types AS t ON t.symbol = j.symbol
  JOIN hafd.blocks AS b ON b.num = _block_num
  JOIN hafd.accounts AS a ON a.name = j.holder;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.soulbind(
  IN _block_num INT,
  IN _account hive.account_name_type,
  IN _json JSONB
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
BEGIN
  UPDATE nfttracker_app.instances
  SET soulbound = j.soulbound
  FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
  WHERE symbol = j.symbol AND id = j.id;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.set_data(
  IN _block_num INT,
  IN _account hive.account_name_type,
  IN _json JSONB
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
BEGIN
  UPDATE nfttracker_app.instances
  SET data = j.data
  FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
  WHERE symbol = j.symbol AND id = j.id;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.transfer(
  IN _block_num INT,
  IN _account hive.account_name_type,
  IN _json JSONB
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
BEGIN
  UPDATE nfttracker_app.instances AS i
  SET holder = j.to
  FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
  WHERE symbol = j.symbol AND id = j.id AND NOT i.soulbound;
END
$$;

RESET ROLE;
