-- Check that transferring NFT instance works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/XYZ', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/XYZ', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_transfer_op(block_num=>3, auth=>'alice', symbol=>'alice/XYZ', id=>1, to_account=>'bob');
CALL insert_nft_transfer_op(block_num=>4, auth=>'alice', symbol=>'alice/XYZ', id=>1, to_account=>'charlie');

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view;
