-- Check that querying NFT instances by transaction hash works correctly

-- Given: Register two types
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/CARD', name=>'Card', owner=>'alice', issuers=>ARRAY['alice']);
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/GEM', name=>'Gem', owner=>'alice', issuers=>ARRAY['alice'], pos=>1);

-- Given: Insert two transactions in block 2
CALL insert_transaction(block_num=>2, trx_in_block=>0::SMALLINT, trx_hash=>decode('aaaa' || repeat('00', 18), 'hex'));
CALL insert_transaction(block_num=>2, trx_in_block=>1::SMALLINT, trx_hash=>decode('bbbb' || repeat('00', 18), 'hex'));

-- Given: Issue 3 CARD + 2 GEM in transaction A, 1 CARD in transaction B
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/CARD', holder=>'bob', data=>'{"n":1}', tags=>ARRAY['t1']::nfttracker_app.tags, soulbound=>FALSE, pos=>0, trx_in_block=>0::SMALLINT);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/CARD', holder=>'bob', data=>'{"n":2}', tags=>ARRAY['t2']::nfttracker_app.tags, soulbound=>FALSE, pos=>1, trx_in_block=>0::SMALLINT);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/CARD', holder=>'charlie', data=>'{"n":3}', tags=>ARRAY['t3']::nfttracker_app.tags, soulbound=>FALSE, pos=>2, trx_in_block=>0::SMALLINT);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/GEM', holder=>'charlie', data=>'{"g":1}', tags=>ARRAY['r1']::nfttracker_app.tags, soulbound=>FALSE, pos=>3, trx_in_block=>0::SMALLINT);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/GEM', holder=>'bob', data=>'{"g":2}', tags=>ARRAY['r2']::nfttracker_app.tags, soulbound=>TRUE, pos=>4, trx_in_block=>0::SMALLINT);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/CARD', holder=>'bob', data=>'{"n":4}', tags=>ARRAY['t4']::nfttracker_app.tags, soulbound=>TRUE, pos=>5, trx_in_block=>1::SMALLINT);

-- When
CALL nfttracker_sync_blocks();

-- Then: Query by trx A hash -> 5 results (3 CARD + 2 GEM) with correct creator/symbol
SELECT id IS NOT NULL AS has_id, creator, symbol, holder, data, tags, soulbound
FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18)));

-- Then: Query by trx B hash -> 1 result
SELECT id IS NOT NULL AS has_id, creator, symbol, holder, data, tags, soulbound
FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('bbbb' || repeat('00', 18)));

-- Then: Query by nonexistent hash -> 0 results
SELECT count(*) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx(repeat('ff', 20)));

-- Then: Pagination - count=2 returns first 2 of 5
SELECT count(*) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), 2));

-- Then: Pagination - last_id from first page skips first 2, returns remaining 3
SELECT count(*) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), NULL,
    (SELECT MAX(id) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), 2)))));

-- Then: Pagination - count=2 + last_id returns page 2 of 3 pages
SELECT creator, symbol, holder FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), 2,
    (SELECT MAX(id) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), 2)))));

-- Then: Pagination - page 3 (last page) returns final 1 instance
SELECT count(*) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), 2,
    (SELECT MAX(id) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), 4)))));

-- Then: Pagination - last_id past final instance returns 0
SELECT count(*) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18), NULL,
    (SELECT MAX(id) FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaaa' || repeat('00', 18))))));

-- Then: Invalid hex characters -> error
SELECT * FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('not_valid_hex'));

-- Then: Odd-length hex string -> error
SELECT * FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aaa'));

-- Then: Too short (valid hex but wrong length) -> error
SELECT * FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx('aabb'));

-- Then: Empty string -> error
SELECT * FROM unnest(nfttracker_endpoints.get_nft_instances_by_trx(''));
