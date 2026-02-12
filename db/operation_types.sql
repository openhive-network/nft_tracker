SET ROLE nfttracker_owner;

CREATE SCHEMA IF NOT EXISTS nfttracker_backend AUTHORIZATION nfttracker_owner;

-- Operation type lookups for NFT Tracker
-- Provide semantic names instead of magic numbers scattered throughout the code.
--
-- NFT Tracker processes custom_json operations (op_type_id 18) with id='NFT'.
-- HAF stores the custom_json id in hafd.custom_json_types and exposes
-- custom_json_type_id on operations_view for efficient filtering.

-- custom_json operation type (op_type_id 18)
CREATE OR REPLACE FUNCTION nfttracker_backend.op_custom_json()
RETURNS SMALLINT LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN (SELECT id FROM hafd.operation_types WHERE name = 'hive::protocol::custom_json_operation');
END;
$$;

-- custom_json_type_id for 'NFT' operations
CREATE OR REPLACE FUNCTION nfttracker_backend.custom_json_nft_type_id()
RETURNS SMALLINT LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN (SELECT id FROM hafd.custom_json_types WHERE custom_json_id = 'NFT');
END;
$$;

RESET ROLE;
