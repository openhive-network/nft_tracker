-- Check that issuer that is not an owner can issue NFT

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['bob', 'charlie'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'bob', symbol=>'alice/ABC', holder=>'bob', data=>'{"from": "bob"}', tags=>ARRAY['xyz']::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>3, auth=>'charlie', symbol=>'alice/ABC', holder=>'bob', data=>'{"from": "charlie"}', tags=>ARRAY['xyz']::nfttracker_app.tags, soulbound=>FALSE);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at = created_at FROM instances_view;
