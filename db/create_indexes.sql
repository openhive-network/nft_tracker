SET ROLE nfttracker_owner;

-- Create a partial index on hafd.operations for 'NFT' custom_json operations.
-- This is highly selective since NFT operations are a tiny fraction of all
-- custom_json traffic (which also includes Splinterlands, Hive Engine, etc.).
--
-- Requires HAF with hive.create_custom_json_type_index() and the
-- custom_json_type_id column. On older HAF versions, gracefully does nothing.

DO $$
BEGIN
    -- Check if the HAF function exists (graceful fallback for older HAF)
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'hive' AND p.proname = 'create_custom_json_type_index'
    ) THEN
        RAISE NOTICE 'hive.create_custom_json_type_index() not available — skipping (older HAF?)';
        RETURN;
    END IF;

    PERFORM hive.create_custom_json_type_index(ARRAY['NFT']);
END
$$;

RESET ROLE;
