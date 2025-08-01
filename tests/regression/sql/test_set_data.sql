-- Check that setting custom data on NFT instance works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', name=>'test', symbol=>'XYZ', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'XYZ', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, souldbound=>FALSE);
CALL insert_nft_set_data_op(block_num=>3, auth=>'alice', symbol=>'XYZ', id=>1, data=>'{"key1": "value1"}'::jsonb);
CALL insert_nft_set_data_op(block_num=>4, auth=>'alice', symbol=>'XYZ', id=>1, data=>'{"key2": "value2"}'::jsonb);

-- When
CALL nfttracker_app.main('nfttracker_app', 4);

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT ALL(updated_at > created_at) FROM instances_view;
