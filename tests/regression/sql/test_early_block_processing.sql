-- Check that nfttracker_app processes NFT operations while hived replays with
-- psql-massive-index-policy=keep-monotonic: blocks are delivered once the kept core
-- indexes exist, block processing reads no table whose indexes are all deferred,
-- and the NFT custom_json index is registered once hived has written the 'NFT' type.
-- Skipped on a HAF without early block processing (haf#379).

SELECT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'hive' AND p.proname = 'app_context_set_early_block_processing'
) AS haf_has_early_block_processing \gset

\if :haf_has_early_block_processing
\i sql/early_block_processing_steps.sql
\else
\echo 'SKIP: HAF has no hive.app_context_set_early_block_processing() (haf#379)'
\endif
