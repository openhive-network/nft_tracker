-- Check that soulbound instances can be burned by transferring to "null" account

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/XYZ', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/XYZ', holder=>'alice', data=>'{"bound": false}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>2, auth=>'alice', symbol=>'alice/XYZ', holder=>'alice', data=>'{"bound": true}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>3, auth=>'alice', symbol=>'alice/XYZ', ids=>ARRAY[1], soulbound=>TRUE);
CALL insert_nft_transfer_op(block_num=>4, pos=>1, auth=>'alice', symbol=>'alice/XYZ', ids=>ARRAY[1], to_account=>'null');
CALL insert_nft_transfer_op(block_num=>4, pos=>2, auth=>'alice', symbol=>'alice/XYZ', ids=>ARRAY[2], to_account=>'null');
CALL insert_nft_transfer_op(block_num=>4, pos=>3, auth=>'alice', symbol=>'alice/XYZ', ids=>ARRAY[1], to_account=>'alice');
CALL insert_nft_transfer_op(block_num=>4, pos=>4, auth=>'alice', symbol=>'alice/XYZ', ids=>ARRAY[2], to_account=>'alice');

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view;
