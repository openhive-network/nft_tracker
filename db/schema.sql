CREATE SCHEMA IF NOT EXISTS nfttracker_app AUTHORIZATION nfttracker_owner;

CREATE DOMAIN nfttracker_app.symbol AS VARCHAR(10)
CHECK (value = UPPER(value));

CREATE DOMAIN nfttracker_app.tags AS VARCHAR(8)[]
CHECK (array_length(value, 1) <= 4);

CREATE TABLE IF NOT EXISTS nfttracker_app.types (
    id BIGSERIAL PRIMARY KEY,
    creator INTEGER NOT NULL REFERENCES hafd.accounts(id),
    owner INTEGER NOT NULL REFERENCES hafd.accounts(id),
    symbol nfttracker_app.symbol NOT NULL,
    name VARCHAR(255) NOT NULL,
    max_count INTEGER,  -- NULL means unlimited,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE (creator, symbol)
);

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_creator_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Cannot update creator for type=%.', NEW.id;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_creator_update
BEFORE UPDATE OF creator ON nfttracker_app.types
FOR EACH ROW
EXECUTE FUNCTION nfttracker_app.prevent_creator_update();

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_symbol_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Cannot update symbol for type=%.', NEW.id;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_symbol_update
BEFORE UPDATE OF symbol ON nfttracker_app.types
FOR EACH ROW
EXECUTE FUNCTION nfttracker_app.prevent_symbol_update();

CREATE OR REPLACE FUNCTION nfttracker_app.prevent_increment_max_count()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Cannot increment max_count for type=%.', NEW.id;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_increment_max_count
BEFORE UPDATE OF max_count ON nfttracker_app.types
FOR EACH ROW
WHEN (NEW.max_count > OLD.max_count)
EXECUTE FUNCTION nfttracker_app.prevent_increment_max_count();

CREATE TABLE IF NOT EXISTS nfttracker_app.authorized_issuers (
    type_id BIGINT NOT NULL REFERENCES nfttracker_app.types(id) ON DELETE CASCADE,
    account_id INTEGER NOT NULL REFERENCES hafd.accounts(id),
    PRIMARY KEY (type_id, account_id)
);

CREATE TABLE IF NOT EXISTS nfttracker_app.instances (
    id BIGSERIAL PRIMARY KEY,
    type_id BIGINT NOT NULL REFERENCES nfttracker_app.types(id),
    holder integer NOT NULL REFERENCES hafd.accounts(id),
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

CREATE TRIGGER trg_prevent_soulbound_unset
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
