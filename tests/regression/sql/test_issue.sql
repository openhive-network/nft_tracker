-- Check that issuing an instance of registered NFT type works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/ABC', holder=>'bob', data=>'{"foo": "bar"}', tags=>ARRAY['xyz']::nfttracker_app.tags, soulbound=>FALSE);

-- When
CALL nfttracker_app.main('nfttracker_app', 2);

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT ALL(updated_at = created_at) FROM instances_view;
