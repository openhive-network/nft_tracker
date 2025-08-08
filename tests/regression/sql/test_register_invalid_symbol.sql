-- Check that registering a new NFT type works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/*', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/123', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'alice', symbol=>'alice/abc', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>4, auth=>'alice', symbol=>'alice/X/Y', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>5, auth=>'alice', symbol=>'alice/X?Y', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>6, auth=>'alice', symbol=>'alice/X+Y', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>7, auth=>'alice', symbol=>'alice/ĘĄ', name=>'invalid', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
