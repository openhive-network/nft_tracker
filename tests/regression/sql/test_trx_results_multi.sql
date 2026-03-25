-- Check that transaction results track subsequent_no for multi-action arrays

-- Given: A transaction with mixed actions in a single array
CALL insert_transaction(block_num=>1, trx_in_block=>0::SMALLINT, trx_hash=>decode('aaaa' || repeat('00', 18), 'hex'));
CALL insert_nft_ops(block_num=>1, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/CARD', name=>'Card', owner=>'alice', issuers=>ARRAY['alice']),
  nft_modify_op(symbol=>'alice/CARD', name=>'Card v2'),
  nft_issue_op(symbol=>'alice/CARD', holder=>'alice', data=>'{"n":1}', tags=>ARRAY['t1']::nfttracker_app.tags, soulbound=>FALSE),
  nft_transfer_op(symbol=>'alice/CARD', ids=>ARRAY[expected_instance_id(1, 0, 1, 2)]::NUMERIC[], to_account=>'bob'),
  nft_register_op(symbol=>'alice/CARD', name=>'Dup', owner=>'alice', issuers=>ARRAY['alice']),
  nft_set_data_op(symbol=>'alice/CARD', ids=>ARRAY[expected_instance_id(1, 0, 1, 2)]::NUMERIC[], data=>'{"updated":true}')
]);

-- When
CALL nfttracker_sync_blocks();

-- Then: 6 results with distinct subsequent_no, action #4 (duplicate register) fails
SELECT op_pos, subsequent_no, action, symbol, account, success, error_message
FROM unnest(nfttracker_endpoints.get_trx_results('aaaa' || repeat('00', 18)));
