-- Check that modifying properties of unowned type fails

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_modify_op(block_num=>2, auth=>'bob', symbol=>'alice/ABC', name=>'test-mod', owner=>'bob', issuers=>ARRAY['bob'], max_count=>11);

-- When
CALL nfttracker_app.main('nfttracker_app', 2);

-- Then
SELECT creator, owner, symbol::TEXT, name::TEXT, max_count, issuers::TEXT[] FROM types_view;
SELECT ALL(updated_at = created_at) FROM types_view;
