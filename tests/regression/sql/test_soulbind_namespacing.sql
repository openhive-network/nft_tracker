-- Check that soulbinding respects namespacing

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice']::hive.account_name_type[], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'bob', symbol=>'bob/ABC', name=>'test', owner=>'bob', issuers=>ARRAY['bob']::hive.account_name_type[], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'charlie', symbol=>'charlie/ABC', name=>'test', owner=>'charlie', issuers=>ARRAY['charlie']::hive.account_name_type[], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>2, auth=>'bob', symbol=>'bob/ABC', holder=>'bob', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>3, auth=>'charlie', symbol=>'charlie/ABC', holder=>'charlie', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_soulbind_op(block_num=>4, pos=>1, auth=>'alice', symbol=>'alice/ABC', id=>1, soulbound=>TRUE);

-- When
CALL nfttracker_app.main('nfttracker_app', 4);

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at > created_at FROM instances_view WHERE id=1;
SELECT updated_at = created_at FROM instances_view WHERE id>1;
