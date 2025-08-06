-- Check that transferring soulbound NFT instance is disallowed

-- Given
-- unsoulbound NFT that's later soulbound
CALL insert_nft_register_op(block_num=>1, pos=>0, auth=>'alice', symbol=>'alice/AAA', name=>'foo', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_issue_op(block_num=>2, pos=>0, auth=>'alice', symbol=>'alice/AAA', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_soulbind_op(block_num=>3, pos=>0, auth=>'alice', symbol=>'alice/AAA', id=>1, soulbound=>TRUE);
CALL insert_nft_transfer_op(block_num=>4, pos=>0, auth=>'alice', symbol=>'alice/AAA', id=>1, to_account=>'dan');
-- NFT soulbound on creation
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'bob', symbol=>'bob/BBB', name=>'bar', owner=>'bob', issuers=>ARRAY['bob'], max_count=>10);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'bob', symbol=>'bob/BBB', holder=>'bob', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>TRUE);
CALL insert_nft_transfer_op(block_num=>3, pos=>1, auth=>'bob', symbol=>'bob/BBB', id=>2, to_account=>'dan');

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view WHERE symbol='AAA';
SELECT updated_at = created_at FROM instances_view WHERE symbol='BBB';
