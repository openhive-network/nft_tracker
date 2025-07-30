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
    UPDATE nfttracker_app.types
    SET
      name = j.name,
      owner = a.id,
      max_count = j.max_count,
      updated_at = b.created_at
    FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
    JOIN hafd.blocks AS b ON b.num = _block_num
    JOIN hafd.accounts AS a ON a.name = j.owner
    WHERE symbol = j.symbol
    RETURNING id
  ),
  insert_issuers AS (
    INSERT INTO nfttracker_app.issuers (type_id, account_id)
    SELECT t.id, a.id
    FROM update_type AS t
    JOIN hafd.accounts AS a ON a.name = ANY(json->'issuers'::text[])
    ON CONFLICT (type_id, account_id) DO NOTHING
    RETURNING 1
  ),
  delete_issuers AS (
    DELETE FROM nfttracker_app.issuers
    USING insert_issuers
    WHERE symbol = _json->>'symbol' AND account_id not in (json->'issuers')::text[]
    RETURNING 1
  )
  SELECT COUNT(*) INTO _count FROM delete_issuers;
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
    j.type_id,
    a.id,
    j.data,
    j.tags,
    j.soulbound,
    b.created_at,
    b.created_at
  FROM jsonb_to_record(_json) AS j(symbol nfttracker_app.symbol, name text, max_count int, owner hive.account_name_type)
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
