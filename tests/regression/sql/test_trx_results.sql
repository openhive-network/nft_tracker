-- Check that transaction results are recorded and queryable

-- Given: Insert transactions for blocks 1 and 2
CALL insert_transaction(block_num=>1, trx_in_block=>0::SMALLINT, trx_hash=>decode('aaaa' || repeat('00', 18), 'hex'));
CALL insert_transaction(block_num=>2, trx_in_block=>0::SMALLINT, trx_hash=>decode('bbbb' || repeat('00', 18), 'hex'));
CALL insert_transaction(block_num=>3, trx_in_block=>0::SMALLINT, trx_hash=>decode('cccc' || repeat('00', 18), 'hex'));
CALL insert_transaction(block_num=>4, trx_in_block=>0::SMALLINT, trx_hash=>decode('dddd' || repeat('00', 18), 'hex'));

-- Given: Register a type (success) + duplicate register (failure) in trx A (block 1)
CALL insert_nft_register_op(block_num=>1, pos=>0, auth=>'alice', symbol=>'alice/CARD', name=>'Card', owner=>'alice', issuers=>ARRAY['alice']);
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/CARD', name=>'Card2', owner=>'alice', issuers=>ARRAY['alice']);

-- Given: Issue an instance in trx B (block 2, success)
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/CARD', holder=>'bob', data=>'{"n":1}', tags=>ARRAY['t1']::nfttracker_app.tags, soulbound=>FALSE);

-- Given: Failed transfer in trx C (block 3, charlie is not the holder)
CALL insert_nft_transfer_op(block_num=>3, auth=>'charlie', symbol=>'alice/CARD',
    ids=>ARRAY[expected_instance_id(2, 0, 1)]::NUMERIC[],
    to_account=>'charlie');

-- Given: Successful transfer in trx D (block 4, bob is the holder)
CALL insert_nft_transfer_op(block_num=>4, auth=>'bob', symbol=>'alice/CARD',
    ids=>ARRAY[expected_instance_id(2, 0, 1)]::NUMERIC[],
    to_account=>'charlie');

-- When
CALL nfttracker_sync_blocks();

-- Then: Trx A has 2 results (1 success + 1 failure with error message)
SELECT op_pos, subsequent_no, action, symbol, account, success, error_message
FROM unnest(nfttracker_endpoints.get_trx_results('aaaa' || repeat('00', 18)));

-- Then: Trx B has 1 success result
SELECT op_pos, subsequent_no, action, symbol, account, success, error_message
FROM unnest(nfttracker_endpoints.get_trx_results('bbbb' || repeat('00', 18)));

-- Then: Trx C has 1 failure result
SELECT op_pos, subsequent_no, action, symbol, account, success, error_message
FROM unnest(nfttracker_endpoints.get_trx_results('cccc' || repeat('00', 18)));

-- Then: Trx D has 1 success result (transfer)
SELECT op_pos, subsequent_no, action, symbol, account, success, error_message
FROM unnest(nfttracker_endpoints.get_trx_results('dddd' || repeat('00', 18)));

-- Then: Nonexistent trx returns empty
SELECT count(*) FROM unnest(nfttracker_endpoints.get_trx_results(repeat('ff', 20)));

-- Then: Pagination - count=1 returns first of 2
SELECT count(*) FROM unnest(nfttracker_endpoints.get_trx_results('aaaa' || repeat('00', 18), 1));

-- Then: Pagination - last_id skips first result
SELECT count(*) FROM unnest(nfttracker_endpoints.get_trx_results('aaaa' || repeat('00', 18), NULL,
    (SELECT MIN(id) FROM unnest(nfttracker_endpoints.get_trx_results('aaaa' || repeat('00', 18))))));

-- Then: Invalid hex -> error
SELECT * FROM unnest(nfttracker_endpoints.get_trx_results('not_valid_hex'));

-- Then: Empty string -> error
SELECT * FROM unnest(nfttracker_endpoints.get_trx_results(''));
