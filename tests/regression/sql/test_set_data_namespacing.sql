-- Check that set_data respects namespacing

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice']::hafd.account_name_type[], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'bob', symbol=>'bob/ABC', name=>'test', owner=>'bob', issuers=>ARRAY['bob']::hafd.account_name_type[], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'charlie', symbol=>'charlie/ABC', name=>'test', owner=>'charlie', issuers=>ARRAY['charlie']::hafd.account_name_type[], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{"v": "orig"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>2, auth=>'bob', symbol=>'bob/ABC', holder=>'bob', data=>'{"v": "orig"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>3, auth=>'charlie', symbol=>'charlie/ABC', holder=>'charlie', data=>'{"v": "orig"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_set_data_op(block_num=>3, pos=>1, auth=>'alice', symbol=>'alice/ABC', ids=>ARRAY[expected_instance_id(2,1,1)], data=>'{"v": "updated"}');

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view WHERE id=expected_instance_id(2,1,1);
SELECT updated_at = created_at FROM instances_view WHERE id<>expected_instance_id(2,1,1);
