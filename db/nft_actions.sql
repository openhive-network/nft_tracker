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
DECLARE
  _symbol nfttracker_app.symbol;
BEGIN
  _symbol := _json->>'symbol';
  IF _symbol.namespace <> _account THEN
    RAISE EXCEPTION '% is disallowed to register NFT types in namespace %', _account, _symbol.namespace;
  END IF;
  WITH json_fields AS (
    SELECT
      _symbol.name AS symbol_name,
      j.name,
      j.max_count,
      j.owner
    FROM jsonb_to_record(_json) AS j(name text, max_count int, owner hive.account_name_type)
  )
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
    j.symbol_name,
    j.name,
    j.max_count,
    b.created_at,
    b.created_at
  FROM json_fields AS j
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
  _symbol nfttracker_app.symbol;
  _count BIGINT;
BEGIN
  _symbol := _json->>'symbol';
  IF _symbol.namespace <> _account THEN
    RAISE EXCEPTION '% is disallowed to modify NFT types in namespace %', _account, _symbol.namespace;
  END IF;
  WITH json_fields AS (
    SELECT
      _symbol.name AS symbol_name,
      _symbol.namespace AS symbol_namespace,
      j.name,
      j.max_count,
      j.owner
    FROM jsonb_to_record(_json) AS j(symbol text, name text, max_count int, owner hive.account_name_type)
  ),
  update_type AS (
    UPDATE nfttracker_app.types AS t
    SET
      name = j.name,
      owner = a.id,
      max_count = j.max_count,
      updated_at = b.created_at
    FROM json_fields AS j
    JOIN hafd.blocks AS b ON b.num = _block_num
    JOIN hafd.accounts AS a ON a.name = j.owner
    JOIN hafd.accounts AS ns ON ns.name = j.symbol_namespace
    WHERE t.symbol = j.symbol_name
      AND t.creator = ns.id
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
  FROM jsonb_to_record(_json) AS j(symbol text, data jsonb, tags nfttracker_app.tags, soulbound boolean, holder hive.account_name_type)
  JOIN nfttracker_app.types AS t ON t.symbol = (j.symbol::nfttracker_app.symbol).name
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
  UPDATE nfttracker_app.instances AS i
  SET
    soulbound = j.soulbound,
    updated_at = b.created_at
  FROM jsonb_to_record(_json) AS j(symbol text, id INT, soulbound boolean)
  JOIN nfttracker_app.types AS t ON t.symbol = (j.symbol::nfttracker_app.symbol).name
  JOIN hafd.blocks AS b ON b.num = _block_num
  WHERE i.id = j.id AND i.type_id = t.id;
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
  UPDATE nfttracker_app.instances AS i
  SET
    data = j.data,
    updated_at = b.created_at
  FROM jsonb_to_record(_json) AS j(symbol text, id INT, data jsonb)
  JOIN nfttracker_app.types AS t ON t.symbol = (j.symbol::nfttracker_app.symbol).name
  JOIN hafd.blocks AS b ON b.num = _block_num
  WHERE i.id = j.id AND i.type_id = t.id;
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
  SET
    holder = a.id,
    updated_at = b.created_at
  FROM jsonb_to_record(_json) AS j(symbol text, id INT, "to" hive.account_name_type)
  JOIN nfttracker_app.types AS t ON t.symbol = (j.symbol::nfttracker_app.symbol).name
  JOIN hafd.blocks AS b ON b.num = _block_num
  JOIN hafd.accounts AS a ON a.name = j."to"
  WHERE i.id = j.id AND i.type_id = t.id AND NOT i.soulbound;
END
$$;

RESET ROLE;
