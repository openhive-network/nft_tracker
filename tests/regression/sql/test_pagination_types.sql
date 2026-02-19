-- Test pagination for get_nft_types endpoint

-- Register 3 types in the same block with different positions to avoid duplicate keys
CALL insert_nft_register_op(block_num=>1, pos=>0, auth=>'alice', symbol=>'alice/A', name=>'t1', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/B', name=>'t2', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/C', name=>'t3', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);

CALL nfttracker_sync_blocks();

-- Verify all 3 types exist
SELECT COUNT(*) FROM types_view;

-- count=1 => 1
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_types(1, NULL));

-- count=2 => 2
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_types(2, NULL));

-- no count => all 3
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_types(NULL, NULL));

-- after id=1 => 2
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_types(NULL, 1));

-- count=1 after id=1 => 1
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_types(1, 1));

-- after last id => 0
SELECT COUNT(*) FROM unnest(nfttracker_endpoints.get_nft_types(10, 3));
