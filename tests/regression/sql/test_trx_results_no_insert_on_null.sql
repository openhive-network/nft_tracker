-- Check that operations with null action or null symbol do not insert into operation_results

-- Given: A valid register, then ops with missing action and missing symbol
CALL insert_transaction(block_num=>1, trx_in_block=>0::SMALLINT, trx_hash=>decode('aaaa' || repeat('00', 18), 'hex'));
CALL insert_nft_register_op(block_num=>1, pos=>0, auth=>'alice', symbol=>'alice/CARD', name=>'Card', owner=>'alice', issuers=>ARRAY['alice']);
CALL insert_nft_operation(block_num=>1, pos=>1, auth=>'alice', data=>'{"action": null, "symbol": "alice/CARD"}'::jsonb);
CALL insert_nft_operation(block_num=>1, pos=>2, auth=>'alice', data=>'{"action": "register", "symbol": null}'::jsonb);
CALL insert_nft_operation(block_num=>1, pos=>3, auth=>'alice', data=>'{"action": null, "symbol": null}'::jsonb);

-- When
CALL nfttracker_sync_blocks();

-- Then: Only the valid register is recorded
SELECT action, symbol, account, success, error_message FROM nfttracker_app.operation_results;
