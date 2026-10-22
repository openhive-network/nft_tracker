-- The steps of test_early_block_processing.sql, run only on a HAF with early
-- block processing so that the skip output does not echo them.

-- Given: the context opted in at install, and a reinstall over it opts in again
SELECT early_block_processing FROM hafd.contexts WHERE name = 'nfttracker_app';
SELECT hive.app_context_set_early_block_processing(ARRAY['nfttracker_app']::hive.contexts_group, FALSE);
\set ECHO none
\set QUIET on
SET client_min_messages = warning;
\i ../../db/schema.sql
RESET ROLE;
RESET client_min_messages;
\set QUIET off
\set ECHO all
SELECT early_block_processing FROM hafd.contexts WHERE name = 'nfttracker_app';

CREATE TABLE delivered(first_block INT, last_block INT, stage TEXT, deferred_table_scans BIGINT);

-- Scans of the hafd tables whose indexes are all deferred, and of their indexes,
-- made so far by the current transaction.
CREATE FUNCTION deferred_table_scans()
RETURNS BIGINT
LANGUAGE sql
AS $$
  SELECT COALESCE(sum(pg_stat_get_xact_numscans(r.oid)), 0)::BIGINT
  FROM (
    SELECT c.oid FROM pg_class c
    WHERE c.oid IN ('hafd.account_operations'::regclass, 'hafd.transactions'::regclass, 'hafd.transactions_multisig'::regclass)
    UNION ALL
    SELECT i.indexrelid FROM pg_index i
    WHERE i.indrelid IN ('hafd.account_operations'::regclass, 'hafd.transactions'::regclass, 'hafd.transactions_multisig'::regclass)
  ) r(oid);
$$;

-- The haf_app_driver.py loop: hive.app_next_iteration, then the procedure the
-- application registered for each delivered range.
CREATE PROCEDURE drive_nfttracker(_iterations INT)
LANGUAGE plpgsql
AS $$
DECLARE
  _range hive.blocks_range;
  _scans BIGINT;
BEGIN
  FOR i IN 1 .. _iterations LOOP
    CALL hive.app_next_iteration(ARRAY['nfttracker_app']::hive.contexts_group, _range, _wait => FALSE);
    IF _range IS NOT NULL THEN
      _scans := deferred_table_scans();
      CALL nfttracker_app.process_blocks(_range);
      INSERT INTO delivered
      VALUES (_range.first_block, _range.last_block, hive.get_current_stage_name('nfttracker_app'),
              deferred_table_scans() - _scans);
    END IF;
  END LOOP;
END
$$;

CREATE VIEW nft_index_registrations AS
SELECT count(*) AS registered
FROM hafd.indexes_constraints
WHERE index_constraint_name ~ '^hive_operations_custom_json_types_[0-9_]+_idx$'
  AND contexts @> ARRAY[hive.get_context_id('nfttracker_app')];

-- hived is in its massive sync, which reports irreversible blocks by
-- hive.end_massive_sync() and has not written the 'NFT' type yet
DELETE FROM hafd.events_queue WHERE id > 0;
SELECT hive.initialize_extension_data();
DELETE FROM hafd.indexes_constraints WHERE index_constraint_name ~ '^hive_operations_custom_json_types_[0-9_]+_idx$';
DELETE FROM hafd.custom_json_types WHERE custom_json_id = 'NFT';
SET client_min_messages = warning;

-- When: hived replays under the default drop-all policy
SELECT hive.disable_fk_of_irreversible();
SELECT hive.disable_indexes_of_irreversible('drop-all');
SELECT hive.set_sync_state('REINDEX');
SELECT hive.end_massive_sync(5);
SET client_min_messages = error;
CALL drive_nfttracker(5);
SET client_min_messages = warning;

-- Then: nothing is delivered before HAF restores its indexes
SELECT hive.is_instance_ready_for_block_processing() AS ready_for_block_processing;
SELECT count(*) AS delivered_ranges FROM delivered;
SELECT hive.app_get_current_block_num('nfttracker_app') AS current_block;
SELECT nfttracker_backend.get_sync_status();

-- When: hived replays under keep-monotonic, still before the 'NFT' type exists
SELECT hive.enable_indexes_of_irreversible();
SELECT hive.disable_indexes_of_irreversible('keep-monotonic');
SELECT hive.is_instance_ready() AS ready,
       hive.is_instance_ready_for_block_processing() AS ready_for_block_processing,
       hive.are_core_indexes_created('hafd.transactions', 'pk_hive_transactions') AS trx_hash_index;
SET client_min_messages = error;
CALL drive_nfttracker(5);
SET client_min_messages = warning;

-- Then: blocks are processed while hived replays, the index waits for the type
SELECT * FROM delivered ORDER BY first_block;
SELECT * FROM nft_index_registrations;

-- When: hived writes the 'NFT' type and NFT operations in the next blocks
INSERT INTO hafd.custom_json_types(custom_json_id) VALUES ('NFT');
CALL insert_nft_register_op(block_num=>6, pos=>1, auth=>'alice', symbol=>'alice/CARD', name=>'card', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_issue_op(block_num=>7, pos=>1, auth=>'alice', symbol=>'alice/CARD', holder=>'bob', data=>'{"power": 1}', tags=>ARRAY['rare'], soulbound=>false);
CALL insert_nft_transfer_op(block_num=>8, pos=>1, auth=>'bob', symbol=>'alice/CARD', ids=>ARRAY[expected_instance_id(7, 1, 1)], to_account=>'charlie');
SELECT hive.end_massive_sync(9);
SET client_min_messages = error;
CALL drive_nfttracker(5);
SET client_min_messages = warning;

-- Then: they are processed in the massive stage, still while hived replays,
-- without reading a table whose indexes are deferred, and the index is registered
SELECT hive.is_instance_ready() AS ready;
SELECT * FROM delivered ORDER BY first_block;
SELECT * FROM nft_index_registrations;
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT holder, data, tags, soulbound, creator, symbol FROM instances_view;
SELECT action, symbol, account, success FROM nfttracker_app.operation_results ORDER BY id;

-- The API reports the progress, and refuses lookups by transaction hash
SELECT nfttracker_backend.get_sync_status()->>'last_block_num' AS last_block_num;
SELECT nfttracker_backend.get_trx_results(repeat('ab', 20));
SELECT nfttracker_backend.get_nft_instances_by_trx(repeat('ab', 20));
