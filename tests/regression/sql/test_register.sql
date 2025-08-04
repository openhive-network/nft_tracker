-- Check that registering a new NFT type works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);

-- When
CALL nfttracker_app.main('nfttracker_app', 1);

-- Then
SELECT creator, owner, symbol::TEXT, name::TEXT, max_count FROM types_view;
SELECT ALL(updated_at = created_at) FROM types_view;
