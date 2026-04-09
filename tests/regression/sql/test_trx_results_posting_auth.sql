-- Check that operations using only posting auth (no active auth) are rejected
-- and recorded as failures rather than crashing the block processor.

-- Given: A valid register, then a register using posting auth only
CALL insert_transaction(block_num=>1, trx_in_block=>0::SMALLINT, trx_hash=>decode('aaaa' || repeat('00', 18), 'hex'));
CALL insert_nft_register_op(block_num=>1, pos=>0, auth=>'alice', symbol=>'alice/CARD', name=>'Card', owner=>'alice', issuers=>ARRAY['alice']);
CALL insert_nft_operation_posting_auth(block_num=>1, pos=>1, auth=>'bob', data=>'{"action":"register","name":"BadNFT","symbol":"bob/BAD","owner":"bob","issuers":["bob"]}'::jsonb);

-- When
CALL nfttracker_sync_blocks();

-- Then: Both operations are recorded; the posting-auth one is a failure
SELECT action, symbol, account, success, error_message IS NOT NULL AS has_error FROM nfttracker_app.operation_results ORDER BY id;

-- And only alice/CARD is registered; bob/BAD is not
SELECT creator, symbol, name FROM types_view;
