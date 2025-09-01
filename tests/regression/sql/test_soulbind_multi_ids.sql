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
CALL insert_nft_soulbind_op(block_num=>3, pos=>1, auth=>'alice', symbol=>'alice/A', ids=>ARRAY[1, 2], soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>3, pos=>2, auth=>'alice', symbol=>'alice/Z', ids=>ARRAY[3, 0], soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>3, pos=>3, auth=>'alice', symbol=>'alice/B', ids=>ARRAY[4, 5], soulbound=>TRUE);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view WHERE id<>3;
SELECT updated_at = created_at FROM instances_view WHERE id=3;
