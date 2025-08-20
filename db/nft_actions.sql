SET ROLE nfttracker_owner;

-- Returns true if given account is in the authorized issuers list for the given symbol.
CREATE OR REPLACE FUNCTION nfttracker_app.is_authorized(
  IN _symbol nfttracker_app.symbol,
  IN _account hive.account_name_type
)
  RETURNS bool
  LANGUAGE plpgsql
  STABLE
AS
$$
DECLARE
  _authorized BOOLEAN;
BEGIN
  SELECT COUNT(*) > 0 INTO _authorized
    FROM (
      SELECT
        _symbol.name AS symbol_name,
        _symbol.namespace AS symbol_namespace
    ) AS j
    JOIN hafd.accounts AS a ON a.name = _account
    JOIN hafd.accounts AS ns ON ns.name = j.symbol_namespace
    JOIN nfttracker_app.types AS t ON t.creator = ns.id AND t.symbol = j.symbol_name
    JOIN nfttracker_app.authorized_issuers AS ai ON ai.type_id = t.id AND ai.account_id = a.id;
  RETURN _authorized;
END;
$$;

-- Retruns true if given account is owner of the given symbol.
CREATE OR REPLACE FUNCTION nfttracker_app.is_owner(
  IN _symbol nfttracker_app.symbol,
  IN _account hive.account_name_type
)
RETURNS bool
LANGUAGE plpgsql
STABLE
AS
$$
DECLARE
  _owner BOOLEAN;
BEGIN
  SELECT COUNT(*) > 0 INTO _owner
    FROM nfttracker_app.types AS t
    JOIN hafd.accounts AS a ON a.name = _account
    JOIN hafd.accounts AS ns ON ns.name = _symbol.namespace
    WHERE t.creator = ns.id
      AND t.symbol = _symbol.name
      AND t.owner = a.id;
  RETURN _owner;
END;
$$;

-- Returns true if given account is NFT instance holder.
CREATE OR REPLACE FUNCTION nfttracker_app.is_holder(
  IN _symbol nfttracker_app.symbol,
  IN _id INT,
  IN _account hive.account_name_type
)
RETURNS bool
LANGUAGE plpgsql
STABLE
AS
$$
DECLARE
  _holder BOOLEAN;
BEGIN
  SELECT COUNT(*) > 0 INTO _holder
    FROM nfttracker_app.instances AS i
    JOIN nfttracker_app.types AS t ON t.id = i.type_id
    JOIN hafd.accounts AS a ON a.name = _account
    JOIN hafd.accounts AS ns ON ns.name = _symbol.namespace
    WHERE t.symbol = _symbol.name
      AND t.creator = ns.id
      AND i.id = _id
      AND i.holder = a.id;
  RETURN _holder;
END;
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.is_max_count_reached(
  IN _symbol nfttracker_app.symbol
)
RETURNS bool
LANGUAGE plpgsql
STABLE
AS
$$
DECLARE
  _max_count INT;
  _issued_count INT;
  _type_id INT;
BEGIN
  SELECT id, max_count INTO _type_id, _max_count
    FROM nfttracker_app.types
    WHERE creator = (SELECT id FROM hafd.accounts WHERE name = _symbol.namespace)
      AND symbol = _symbol.name;
  SELECT COUNT(*) INTO _issued_count FROM nfttracker_app.instances WHERE type_id = _type_id;
  RETURN _max_count IS NOT NULL AND _issued_count >= _max_count;
END;
$$;

CREATE OR REPLACE PROCEDURE nfttracker_app.require_account_exists(
  IN _account hive.account_name_type
)
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hafd.accounts WHERE name = _account) THEN
    RAISE EXCEPTION 'Account % does not exist', _account;
  END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE nfttracker_app.require_accounts_exists(
  IN _accounts hive.account_name_type[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  _account hive.account_name_type;
BEGIN
  FOR _account IN SELECT UNNEST(_accounts) LOOP
    CALL nfttracker_app.require_account_exists(_account);
  END LOOP;
END;
$$;

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
  _issuers hive.account_name_type[];
  _max_count INT;
  _name TEXT;
  err_msg TEXT;
  err_constraint TEXT;
  err_column TEXT;
BEGIN
  _symbol := _json->>'symbol';
  _max_count := _json->>'max_count';
  _name := _json->>'name';

  IF _symbol.namespace <> _account THEN
    RAISE EXCEPTION '% is disallowed to register NFT types in namespace %', _account, _symbol.namespace;
  END IF;
  IF _max_count IS NOT NULL AND _max_count <= 0 THEN
    RAISE EXCEPTION 'Invalid max_count value % for NFT %: must be a positive integer', _json->>'max_count', _json->>'symbol';
  END IF;
  IF _name IS NULL OR _name = '' THEN
    RAISE EXCEPTION 'Invalid name value "%" for NFT %: must be a non-empty string', _json->>'name', _json->>'symbol';
  END IF;

  SELECT array_agg(i) INTO _issuers FROM jsonb_array_elements_text(_json->'issuers') AS i;
  CALL nfttracker_app.require_account_exists(_json->>'owner');
  CALL nfttracker_app.require_accounts_exists(_issuers);
  BEGIN
    WITH json_fields AS (
      SELECT
        _symbol.name AS symbol_name,
        j.name,
        j.owner,
        j.issuers
      FROM jsonb_to_record(_json) AS j(name text, owner hive.account_name_type, issuers hive.account_name_type[])
    ),
    new_type AS (
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
        o.id,
        j.symbol_name,
        j.name,
        _max_count,
        b.created_at,
        b.created_at
      FROM json_fields AS j
      JOIN hafd.blocks AS b ON b.num = _block_num
      JOIN hafd.accounts AS o ON o.name = j.owner
      JOIN hafd.accounts AS a ON a.name = _account
      RETURNING id, (SELECT issuers FROM json_fields LIMIT 1) AS issuers
    )
    INSERT INTO nfttracker_app.authorized_issuers (type_id, account_id)
    SELECT t.id, a.id
    FROM new_type AS t
    JOIN hafd.accounts AS a ON a.name = ANY((SELECT issuers FROM json_fields)::hive.account_name_type[]);
  EXCEPTION
    WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS err_msg = MESSAGE_TEXT;
      RAISE EXCEPTION 'NFT type % already exists', _json->>'symbol' USING DETAIL = err_msg;
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS
        err_msg = MESSAGE_TEXT,
        err_column = COLUMN_NAME;
      RAISE '"%" cannot be empty for NFT %', err_COLUMN, _json->>'symbol' USING DETAIL = err_msg;
    WHEN OTHERS THEN
      RAISE;
  END;
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
  _issuers hive.account_name_type[];
  _max_count INT;
  _name TEXT;
BEGIN
  _symbol := _json->>'symbol';
  _max_count := _json->>'max_count';
  _name := _json->>'name';

  IF NOT nfttracker_app.is_owner(_symbol, _account) THEN
    RAISE EXCEPTION '% is disallowed to modify NFT type %', _account, _json->>'symbol';
  END IF;
  IF _max_count IS NOT NULL AND _max_count <= 0 THEN
    RAISE EXCEPTION 'Invalid max_count value % for NFT %: must be a positive integer', _json->>'max_count', _json->>'symbol';
  END IF;
  IF _name IS NOT NULL AND _name = '' THEN
    RAISE EXCEPTION 'Invalid name value "%" for NFT %: must be a non-empty string', _json->>'name', _json->>'symbol';
  END IF;

  SELECT array_agg(i) INTO _issuers FROM jsonb_array_elements_text(_json->'issuers') AS i;
  IF _json->>'owner' IS NOT NULL THEN
    CALL nfttracker_app.require_account_exists(_json->>'owner');
  END IF;
  IF _json->>'issuers' IS NOT NULL THEN
    CALL nfttracker_app.require_accounts_exists(_issuers);
  END IF;
  WITH json_fields AS (
    SELECT
      _symbol.name AS symbol_name,
      _symbol.namespace AS symbol_namespace,
      j.owner
    FROM jsonb_to_record(_json) AS j(symbol text, owner hive.account_name_type)
  ),
  update_type AS (
    UPDATE nfttracker_app.types AS t
    SET
      name = COALESCE(_name, t.name),
      owner = COALESCE(o.id, t.owner),
      max_count = COALESCE(_max_count, t.max_count),
      updated_at = b.created_at
    FROM json_fields AS j
    JOIN hafd.blocks AS b ON b.num = _block_num
    LEFT JOIN hafd.accounts AS o ON o.name = j.owner
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
    WHERE _json->>'issuers' IS NOT NULL
    ON CONFLICT (type_id, account_id) DO NOTHING
    RETURNING 1
  ),
  delete_issuers AS (
    DELETE FROM nfttracker_app.authorized_issuers AS ai
    WHERE _json->>'issuers' IS NOT NULL
      AND ai.type_id IN (SELECT id FROM update_type)
      AND ai.account_id NOT IN (
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
  IF NOT nfttracker_app.is_authorized(_json->>'symbol', _account) THEN
    RAISE EXCEPTION 'Account % is disallowed to issue NFTs %', _account, _json->>'symbol';
  END IF;
  IF nfttracker_app.is_max_count_reached(_json->>'symbol') THEN
    RAISE EXCEPTION 'Max number of instances already issued for NFT %', _json->>'symbol';
  END IF;
  WITH json_fields AS (
    SELECT
      (j.symbol::nfttracker_app.symbol).name AS symbol_name,
      (j.symbol::nfttracker_app.symbol).namespace AS symbol_namespace,
      j.data,
      j.tags,
      j.soulbound,
      j.holder
    FROM jsonb_to_record(_json) AS j(symbol text, data jsonb, tags nfttracker_app.tags, soulbound boolean, holder hive.account_name_type)
  )
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
    h.id,
    j.data,
    j.tags,
    j.soulbound,
    b.created_at,
    b.created_at
  FROM json_fields AS j
  JOIN hafd.blocks AS b ON b.num = _block_num
  JOIN hafd.accounts AS h ON h.name = j.holder
  JOIN hafd.accounts AS ns ON ns.name = j.symbol_namespace
  JOIN hafd.accounts AS i ON i.name = _account
  JOIN nfttracker_app.types AS t ON t.symbol = j.symbol_name AND t.creator = ns.id;
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
  IF NOT nfttracker_app.is_authorized(_json->>'symbol', _account) THEN
    RAISE EXCEPTION 'Account % is disallowed to soulbind NFTs %', _account, _json->>'symbol';
  END IF;
  UPDATE nfttracker_app.instances AS i
  SET
    soulbound = j.soulbound,
    updated_at = b.created_at
  FROM jsonb_to_record(_json) AS j(symbol text, id INT, soulbound boolean)
  JOIN hafd.accounts AS ns ON ns.name = (j.symbol::nfttracker_app.symbol).namespace
  JOIN nfttracker_app.types AS t ON t.symbol = (j.symbol::nfttracker_app.symbol).name AND t.creator = ns.id
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
  IF NOT nfttracker_app.is_authorized(_json->>'symbol', _account) THEN
    RAISE EXCEPTION 'Account % is disallowed to set data on NFTs %', _account, _json->>'symbol';
  END IF;
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
DECLARE
  _symbol nfttracker_app.symbol;
  _id INT;
BEGIN
  _symbol := (_json->>'symbol')::nfttracker_app.symbol;
  _id := (_json->>'id')::INT;
  IF NOT nfttracker_app.is_holder(_symbol, _id, _account) THEN
    RAISE EXCEPTION 'Account % is disallowed to transfer NFT %:%', _account, _json->>'symbol', _id;
  END IF;
  UPDATE nfttracker_app.instances AS i
  SET
    holder = a.id,
    updated_at = b.created_at
  FROM jsonb_to_record(_json) AS j(symbol text, id INT, "to" hive.account_name_type)
  JOIN nfttracker_app.types AS t ON t.symbol = (j.symbol::nfttracker_app.symbol).name
  JOIN hafd.blocks AS b ON b.num = _block_num
  JOIN hafd.accounts AS a ON a.name = j."to"
  WHERE i.id = j.id AND i.type_id = t.id AND (NOT i.soulbound OR j."to" = 'null');
END
$$;

RESET ROLE;
