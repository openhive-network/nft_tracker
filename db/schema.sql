SET ROLE nfttracker_owner;

CREATE SCHEMA IF NOT EXISTS nfttracker_app AUTHORIZATION nfttracker_owner;

CREATE DOMAIN nfttracker_app.symbol_name AS VARCHAR(10);

CREATE DOMAIN nfttracker_app.symbol_namespace AS VARCHAR(16);

CREATE DOMAIN nfttracker_app.positive_integer AS INTEGER
CHECK (value > 0);

CREATE DOMAIN nfttracker_app.typename AS VARCHAR(255)
CHECK (length(value) > 0);

CREATE TYPE nfttracker_app.symbol AS (
    namespace nfttracker_app.symbol_namespace,
    name nfttracker_app.symbol_name
);

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

CREATE CAST (TEXT AS nfttracker_app.symbol) WITH FUNCTION nfttracker_app.text_to_symbol(TEXT) AS implicit;

CREATE DOMAIN nfttracker_app.tags AS VARCHAR(8)[]
CHECK (array_length(value, 1) <= 4);

CREATE TABLE IF NOT EXISTS nfttracker_app.types (
    id BIGSERIAL PRIMARY KEY,
    creator INTEGER NOT NULL,
    owner INTEGER NOT NULL,
    symbol nfttracker_app.symbol_name NOT NULL,
    name nfttracker_app.typename NOT NULL,
    max_count nfttracker_app.positive_integer,  -- NULL means unlimited,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE (creator, symbol)
);

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
    id BIGSERIAL PRIMARY KEY,
    type_id BIGINT NOT NULL REFERENCES nfttracker_app.types(id),
    holder INTEGER NOT NULL,
    data JSONB NOT NULL,
    tags nfttracker_app.tags NOT NULL,
    soulbound BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_nfts_instances_type_id ON nfttracker_app.instances(type_id);

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
