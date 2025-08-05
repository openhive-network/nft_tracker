-- Check that issuing an instance of NFT is not allowed for users not present in the issuers array

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY[]::hive.account_name_type[], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{"foo": "bar"}', tags=>ARRAY['abc']::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>2, auth=>'bob', symbol=>'alice/ABC', holder=>'bob', data=>'{"foo": "bar"}', tags=>ARRAY['abc']::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>2, pos=>3, auth=>'charlie', symbol=>'alice/ABC', holder=>'charlie', data=>'{"foo": "bar"}', tags=>ARRAY['abc']::nfttracker_app.tags, soulbound=>FALSE);

-- When
CALL nfttracker_app.main('nfttracker_app', 2);

-- Then
SELECT COUNT(*) FROM instances_view;
