-- The steps of test_block_range_nft_index.sql, run only on a HAF with block-keyed
-- custom_json type indexes so that the skip output does not echo them.

-- Given: hived's indexes controller has built the index nft_tracker registered
SELECT index_name AS nft_index FROM hafd.custom_json_type_index_requests
WHERE context_id = hive.get_context_id('nfttracker_app') \gset
SELECT command FROM hafd.indexes_constraints WHERE index_constraint_name = :'nft_index' \gexec

-- Given: NFT operations are a tiny share of the custom_json operations
INSERT INTO hafd.custom_json_types(custom_json_id) VALUES ('other');
INSERT INTO hafd.operations (id, trx_in_block, op_type_id, op_pos, body_value, custom_json_type_id)
SELECT hafd.operation_id(b, p), 0, nfttracker_backend.op_custom_json(), p,
       format_custom_json_operation(b, p, 'alice', 'other', '{}')::jsonb,
       (SELECT id FROM hafd.custom_json_types WHERE custom_json_id = 'other')
FROM generate_series(1, 9) AS b, generate_series(1, 3000) AS p;
CALL insert_nft_register_op(block_num=>5, auth=>'alice', symbol=>'alice/XYZ', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
ANALYZE hafd.operations;

CREATE FUNCTION query_plan(_query TEXT)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY EXECUTE 'EXPLAIN ' || _query;
END
$$;

-- When
CREATE TEMPORARY TABLE block_range_plan AS
SELECT plan_line FROM (SELECT nfttracker_app.block_range_data_query(3, 7) AS q) s,
LATERAL query_plan(s.q) AS plan_line;

-- Then
SELECT bool_or(position(:'nft_index' IN plan_line) > 0) AS uses_nft_index FROM block_range_plan;
SELECT bool_or(plan_line ~ 'hive_operations_op_type_id_block_num') AS uses_op_type_index FROM block_range_plan;
SET client_min_messages = error;
CALL nfttracker_sync_blocks();
RESET client_min_messages;
SELECT creator, owner, symbol FROM types_view;
