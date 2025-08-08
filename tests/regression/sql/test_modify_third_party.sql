-- Check modifying NFT type by owner who is not the creator

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'bob', issuers=>ARRAY['dan'], max_count=>12);
CALL insert_nft_modify_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test-alice', owner=>'alice', issuers=>ARRAY['alice'], max_count=>11);
CALL insert_nft_modify_op(block_num=>2, pos=>2, auth=>'bob', symbol=>'alice/ABC', name=>'test-bob', owner=>'bob', issuers=>ARRAY['bob'], max_count=>11);
CALL insert_nft_modify_op(block_num=>2, pos=>3, auth=>'charlie', symbol=>'alice/ABC', name=>'test-charlie', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>11);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at > created_at FROM types_view;
