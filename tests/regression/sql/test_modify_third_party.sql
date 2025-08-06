-- Check that modifying properties of registered NFT type works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'bob', issuers=>ARRAY['dan'], max_count=>12);
CALL insert_nft_modify_op(block_num=>2, pos=>1, auth=>'alice', name=>'test-alice', symbol=>'alice/ABC', owner=>'alice', issuers=>ARRAY['alice'], max_count=>11);
CALL insert_nft_modify_op(block_num=>2, pos=>2, auth=>'bob', name=>'test-bob', symbol=>'alice/ABC', owner=>'bob', issuers=>ARRAY['bob'], max_count=>11);
CALL insert_nft_modify_op(block_num=>2, pos=>3, auth=>'charlie', name=>'test-charlie', symbol=>'alice/ABC', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>11);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at > created_at FROM types_view;
