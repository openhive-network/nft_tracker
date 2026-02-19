SET ROLE nfttracker_owner;

CREATE SCHEMA IF NOT EXISTS nfttracker_backend AUTHORIZATION nfttracker_owner;

-- Operation type lookups for NFT Tracker
-- Provide semantic names instead of magic numbers scattered throughout the code.
--
-- NFT Tracker processes custom_json operations (op_type_id 18) with id='NFT'.

-- custom_json operation type (op_type_id 18)
CREATE OR REPLACE FUNCTION nfttracker_backend.op_custom_json()
RETURNS SMALLINT LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN (SELECT id FROM hafd.operation_types WHERE name = 'hive::protocol::custom_json_operation');
END;
$$;

RESET ROLE;
