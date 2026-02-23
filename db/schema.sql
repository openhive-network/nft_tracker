SET ROLE nfttracker_owner;

CREATE SCHEMA IF NOT EXISTS nfttracker_app AUTHORIZATION nfttracker_owner;

-- Create domains idempotently (no data loss on re-run)
DO $$
BEGIN
    CREATE DOMAIN nfttracker_app.symbol_name AS VARCHAR(10);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE DOMAIN nfttracker_app.symbol_namespace AS VARCHAR(16);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE DOMAIN nfttracker_app.positive_integer AS INTEGER
    CHECK (value > 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE DOMAIN nfttracker_app.typename AS VARCHAR(255)
    CHECK (length(value) > 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Create composite type idempotently
DO $$
BEGIN
    CREATE TYPE nfttracker_app.symbol AS (
        namespace nfttracker_app.symbol_namespace,
        name nfttracker_app.symbol_name
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION nfttracker_app.text_to_symbol(input TEXT)
RETURNS nfttracker_app.symbol AS $$
DECLARE
    parts TEXT[];
    result nfttracker_app.symbol;
BEGIN
    parts := string_to_array(input, '/');

    IF array_length(parts, 1) != 2 THEN
        RAISE EXCEPTION 'Invalid symbol format. Expected "namespace/symbol", got: %', input;
    END IF;

    IF length(parts[1]) > 16 THEN
        RAISE EXCEPTION 'Symbol namespace too long. Maximum 16 characters allowed, got: %', parts[1];
    END IF;

    IF length(parts[2]) > 10 THEN
        RAISE EXCEPTION 'Symbol name too long. Maximum 10 characters allowed, got: %', parts[2];
    END IF;

    IF parts[2] !~ '^[A-Z][A-Z0-9]*$' THEN
        RAISE EXCEPTION 'Invalid symbol name "%"', parts[2];
    END IF;

    result.namespace := parts[1];
    result.name := parts[2];

    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- Create cast idempotently
DO $$
BEGIN
    CREATE CAST (TEXT AS nfttracker_app.symbol)
        WITH FUNCTION nfttracker_app.text_to_symbol(TEXT) AS implicit;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE DOMAIN nfttracker_app.tags AS VARCHAR(8)[]
    CHECK (array_length(value, 1) <= 4);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Damm checksum algorithm (base-10, single-digit result)
-- Used to generate valid NAI check digits for NFT asset symbols.
CREATE OR REPLACE FUNCTION nfttracker_app.damm_checksum(_input TEXT)
RETURNS INT
LANGUAGE plpgsql IMMUTABLE STRICT
AS $$
DECLARE
  _table INT[][] := ARRAY[
    ARRAY[0,3,1,7,5,9,8,6,4,2],
    ARRAY[7,0,9,2,1,5,4,8,6,3],
    ARRAY[4,2,0,6,8,7,1,3,5,9],
    ARRAY[1,7,5,0,9,8,3,4,2,6],
    ARRAY[6,1,2,3,0,4,5,9,7,8],
    ARRAY[3,6,7,4,2,0,9,5,8,1],
    ARRAY[5,8,6,9,7,2,0,1,3,4],
    ARRAY[8,9,4,5,3,6,2,0,1,7],
    ARRAY[9,4,3,8,6,1,7,2,0,5],
    ARRAY[2,5,8,1,4,3,6,7,9,0]
  ];
  _interim INT := 0;
  _ch CHAR;
BEGIN
  FOR i IN 1..length(_input) LOOP
    _ch := substr(_input, i, 1);
    _interim := _table[_interim + 1][(ascii(_ch) - ascii('0')) + 1];
  END LOOP;
  RETURN _interim;
END;
$$;

-- Convert a type_id to a HAF asset_symbol.
-- Offsets by 10,000,000 to avoid reserved NAI range, appends Damm checksum.
CREATE OR REPLACE FUNCTION nfttracker_app.type_id_to_asset_symbol(_type_id BIGINT)
RETURNS hafd.asset_symbol
LANGUAGE plpgsql IMMUTABLE STRICT
AS $$
DECLARE
  _nai_num BIGINT := _type_id + 10000000;
  _nai_str TEXT := _nai_num::TEXT;
  _checksum INT;
BEGIN
  _checksum := nfttracker_app.damm_checksum(_nai_str);
  RETURN hive.asset_symbol_from_nai_string('@@' || _nai_str || _checksum::TEXT, 0::SMALLINT);
END;
$$;

-- Create tables idempotently (preserves existing data)
CREATE TABLE IF NOT EXISTS nfttracker_app.types (
    id BIGSERIAL PRIMARY KEY,
    creator INTEGER NOT NULL,
    owner INTEGER NOT NULL,
    symbol nfttracker_app.symbol_name NOT NULL,
    name nfttracker_app.typename NOT NULL,
    max_count nfttracker_app.positive_integer,  -- NULL means unlimited,
    asset_symbol hafd.asset_symbol,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE (creator, symbol)
);

CREATE OR REPLACE FUNCTION nfttracker_app.set_asset_symbol_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    NEW.asset_symbol := nfttracker_app.type_id_to_asset_symbol(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_set_asset_symbol
BEFORE INSERT ON nfttracker_app.types
FOR EACH ROW
EXECUTE FUNCTION nfttracker_app.set_asset_symbol_on_insert();

CREATE OR REPLACE FUNCTION nfttracker_app.namespace_by_id(_id BIGINT)
RETURNS nfttracker_app.symbol_namespace
AS $$
    SELECT a.name
        FROM nfttracker_app.types AS t
        JOIN hafd.accounts AS a ON a.id = t.creator
        WHERE t.id = _id;
$$ LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_creator_update()
RETURNS TRIGGER AS $$
DECLARE
    _namespace nfttracker_app.symbol_namespace;
BEGIN
    SELECT nfttracker_app.namespace_by_id(NEW.id) INTO _namespace;
    RAISE EXCEPTION 'Creator cannot be changed for %/%.', _namespace, NEW.symbol;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_prevent_creator_update
BEFORE UPDATE OF creator ON nfttracker_app.types
FOR EACH ROW
EXECUTE FUNCTION nfttracker_app.prevent_creator_update();

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_symbol_update()
RETURNS TRIGGER AS $$
DECLARE
    _namespace nfttracker_app.symbol_namespace;
BEGIN
    SELECT nfttracker_app.namespace_by_id(NEW.id) INTO _namespace;
    RAISE EXCEPTION 'Symbol cannot be changed for %/%.', _namespace, NEW.symbol;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_prevent_symbol_update
BEFORE UPDATE OF symbol ON nfttracker_app.types
FOR EACH ROW
EXECUTE FUNCTION nfttracker_app.prevent_symbol_update();

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_increment_max_count()
RETURNS TRIGGER AS $$
DECLARE
    _namespace nfttracker_app.symbol_namespace;
BEGIN
    SELECT nfttracker_app.namespace_by_id(NEW.id) INTO _namespace;
    RAISE EXCEPTION 'Cannot increment max_count for symbol %/%.', _namespace, NEW.symbol;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_prevent_increment_max_count
BEFORE UPDATE OF max_count ON nfttracker_app.types
FOR EACH ROW
WHEN (NEW.max_count > OLD.max_count)
EXECUTE FUNCTION nfttracker_app.prevent_increment_max_count();

CREATE TABLE IF NOT EXISTS nfttracker_app.authorized_issuers (
    type_id BIGINT NOT NULL REFERENCES nfttracker_app.types(id) ON DELETE CASCADE,
    account_id INTEGER NOT NULL,
    PRIMARY KEY (type_id, account_id)
);

CREATE TABLE IF NOT EXISTS nfttracker_app.instances (
    id NUMERIC PRIMARY KEY,
    type_id BIGINT NOT NULL REFERENCES nfttracker_app.types(id),
    holder INTEGER NOT NULL,
    data JSONB NOT NULL,
    tags nfttracker_app.tags NOT NULL,
    soulbound BOOLEAN NOT NULL DEFAULT FALSE,
    operation_id BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_nfts_instances_type_id ON nfttracker_app.instances(type_id);
CREATE INDEX IF NOT EXISTS idx_nfts_instances_holder ON nfttracker_app.instances(holder);
CREATE INDEX IF NOT EXISTS idx_nfts_instances_tags_gin ON nfttracker_app.instances USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_nfts_instances_operation_id ON nfttracker_app.instances(operation_id);

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_soulbound_unset()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Cannot unset soulbound for %: once set, soulbound cannot be reset.', NEW.id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_prevent_soulbound_unset
BEFORE UPDATE OF soulbound ON nfttracker_app.instances
FOR EACH ROW
WHEN (OLD.soulbound = TRUE AND NEW.soulbound = FALSE)
EXECUTE FUNCTION nfttracker_app.prevent_soulbound_unset();

CREATE TABLE IF NOT EXISTS nfttracker_app.nfts_app_status
(
  id SMALLINT PRIMARY KEY CHECK (id = 1),
  continue_processing BOOLEAN NOT NULL
);

INSERT INTO nfttracker_app.nfts_app_status
(id, continue_processing)
VALUES (1, FALSE)
ON CONFLICT (id) DO NOTHING;

-- Check if the custom_json partial index for NFT operations exists and is valid.
-- Returns TRUE if the index exists or if the HAF function is not available (older HAF).
CREATE OR REPLACE FUNCTION nfttracker_app.do_nft_indexes_exist()
RETURNS BOOLEAN
LANGUAGE 'plpgsql' STABLE
AS $$
DECLARE
    __type_id SMALLINT;
    __expected_name TEXT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'hive' AND p.proname = 'create_custom_json_type_index'
    ) THEN
        RETURN TRUE;  -- Not applicable on this HAF version
    END IF;

    __type_id := nfttracker_backend.custom_json_nft_type_id();
    IF __type_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- HAF naming convention: hive_operations_custom_json_types_{id}_idx
    __expected_name := 'hive_operations_custom_json_types_' || __type_id || '_idx';

    RETURN EXISTS (
        SELECT 1
        FROM pg_indexes pi
        JOIN pg_class c ON c.relname = pi.indexname
        JOIN pg_index i ON c.oid = i.indexrelid
        WHERE pi.indexname = __expected_name AND i.indisvalid
    );
END $$;

-- Create the custom_json partial index for NFT operations.
-- Called once at the MASSIVE_PROCESSING → LIVE stage transition.
-- On older HAF versions without create_custom_json_type_index(), does nothing.
CREATE OR REPLACE FUNCTION nfttracker_app.create_nft_indexes()
RETURNS VOID
LANGUAGE 'plpgsql' VOLATILE
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'hive' AND p.proname = 'create_custom_json_type_index'
    ) THEN
        RAISE NOTICE 'hive.create_custom_json_type_index() not available — skipping';
        RETURN;
    END IF;

    IF nfttracker_app.do_nft_indexes_exist() THEN
        RAISE NOTICE 'NFT custom_json index already exists — skipping';
        RETURN;
    END IF;

    RAISE NOTICE 'Creating custom_json type index for NFT operations...';
    PERFORM hive.create_custom_json_type_index(ARRAY['NFT']);
END $$;

DO $$
DECLARE
  synchronization_stages hive.application_stages;
BEGIN
  IF NOT hive.app_context_exists('nfttracker_app') THEN
    synchronization_stages := ARRAY[( 'MASSIVE_PROCESSING', 101, 10000, '3 seconds' ), hive.live_stage()]::hive.application_stages;

    PERFORM hive.app_create_context(
      _name => 'nfttracker_app',
      _schema => 'nfttracker_app',
      _is_forking => FALSE,
      _stages => synchronization_stages
    );
  END IF;
END $$;