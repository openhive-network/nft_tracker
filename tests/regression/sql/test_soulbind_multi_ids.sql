-- Check soulbinding multiple instances

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/B', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'alice', symbol=>'alice/Z', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/A', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>2, auth=>'alice', symbol=>'alice/A', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>3, auth=>'alice', symbol=>'alice/Z', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>4, auth=>'alice', symbol=>'alice/B', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>5, auth=>'alice', symbol=>'alice/B', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_soulbind_op(block_num=>3, pos=>1, auth=>'alice', symbol=>'alice/A', ids=>ARRAY[expected_instance_id(2,1,1), expected_instance_id(2,2,1)], soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>3, pos=>2, auth=>'alice', symbol=>'alice/Z', ids=>ARRAY[expected_instance_id(2,3,3), 0::NUMERIC], soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>3, pos=>3, auth=>'alice', symbol=>'alice/B', ids=>ARRAY[expected_instance_id(2,4,2), expected_instance_id(2,5,2)], soulbound=>TRUE);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view WHERE id<>expected_instance_id(2,3,3);
SELECT updated_at = created_at FROM instances_view WHERE id=expected_instance_id(2,3,3);
