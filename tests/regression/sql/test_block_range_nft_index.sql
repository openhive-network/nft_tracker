-- Check that the statement block_range_data executes for a block range reads the
-- NFT operations through the block-keyed custom_json type index registered by
-- nfttracker_app.register_nft_index(), not through the index of all custom_json
-- operations. Skipped on a HAF whose custom_json type indexes are not keyed on
-- block number (haf#387).

SELECT to_regclass('hafd.custom_json_type_index_requests') IS NOT NULL
  AS haf_has_block_keyed_custom_json_index \gset

\if :haf_has_block_keyed_custom_json_index
\i sql/block_range_nft_index_steps.sql
\else
\echo 'SKIP: HAF does not key custom_json type indexes on block number (haf#387)'
\endif
