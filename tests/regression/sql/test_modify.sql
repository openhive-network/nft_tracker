-- Check that modifying properties of registered NFT type works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_modify_op(block_num=>2, auth=>'alice', name=>'test-mod', symbol=>'alice/ABC', owner=>'bob', issuers=>ARRAY['bob'], max_count=>11);
CALL insert_nft_modify_op(block_num=>3, auth=>'bob', name=>'test-3', symbol=>'alice/ABC', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>12); -- Incrementing max_count should fail

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at > created_at FROM types_view;
