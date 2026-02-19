-- Test pagination for get_nft_instances endpoint

-- Setup: register alice/ABC and issue 3 instances
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'t', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{}', tags=>ARRAY['tag']::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>3, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{}', tags=>ARRAY['tag']::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>4, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{}', tags=>ARRAY['tag']::nfttracker_app.tags, soulbound=>FALSE);

CALL nfttracker_sync_blocks();

-- Verify all 3 instances exist
SELECT COUNT(*) FROM instances_view;

-- count=1 => 1
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_instances('alice','ABC',NULL,1,NULL));

-- count=2 => 2
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_instances('alice','ABC',NULL,2,NULL));

-- no count => all 3
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_instances('alice','ABC',NULL,NULL,NULL));

-- pagination with last_id from first result => 2
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_instances('alice','ABC',NULL,10,
    (SELECT (unnest(nfttracker_endpoints.get_nft_instances('alice','ABC',NULL,1,NULL))).id)::TEXT));

-- after last instance => 0
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_instances('alice','ABC',NULL,10,
    (SELECT MAX(id) FROM instances_view)::TEXT));
