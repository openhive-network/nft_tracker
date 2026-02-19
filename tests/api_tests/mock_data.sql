CALL insert_nft_ops(block_num=>10, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/A', name=>'Alice type A', owner=>'alice', issuers=>ARRAY['alice'], max_count=>2),
  nft_register_op(symbol=>'alice/B', name=>'Alice type B', owner=>'alice', issuers=>ARRAY['alice', 'bob'], max_count=>4),
  nft_register_op(symbol=>'alice/C', name=>'Alice type C', owner=>'alice', issuers=>ARRAY['alice', 'bob', 'dan'], max_count=>6)
]);

CALL insert_nft_ops(block_num=>11, auth=>'bob', ops=>ARRAY[
  nft_register_op(symbol=>'bob/A', name=>'Bob type A', owner=>'bob', issuers=>ARRAY['alice'], max_count=>3),
  nft_register_op(symbol=>'bob/B', name=>'Bob type B', owner=>'bob', issuers=>ARRAY['bob'], max_count=>2),
  nft_register_op(symbol=>'bob/C', name=>'Bob type C', owner=>'bob', issuers=>ARRAY['dan'], max_count=>1)
]);

CALL insert_nft_ops(block_num=>12, auth=>'alice', ops=>ARRAY[
  nft_issue_op(symbol=>'alice/A', holder=>'alice', data=>'{}', tags=>ARRAY['X']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/A', holder=>'alice', data=>'{}', tags=>ARRAY['Y']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/B', holder=>'alice', data=>'{}', tags=>ARRAY['X']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/B', holder=>'bob', data=>'{}', tags=>ARRAY['X']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/B', holder=>'alice', data=>'{}', tags=>ARRAY['Y']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/B', holder=>'bob', data=>'{}', tags=>ARRAY['Y']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/C', holder=>'alice', data=>'{}', tags=>ARRAY['X']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/C', holder=>'bob', data=>'{}', tags=>ARRAY['X']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/C', holder=>'dan', data=>'{}', tags=>ARRAY['X']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/C', holder=>'alice', data=>'{}', tags=>ARRAY['Y']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/C', holder=>'bob', data=>'{}', tags=>ARRAY['Y']::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/C', holder=>'dan', data=>'{}', tags=>ARRAY['Y']::nfttracker_app.tags, soulbound=>FALSE)
]);

-- Insert missing blocks for mock data above
INSERT INTO hafd.blocks
SELECT
  hafd.make_block_id(block_num, 1),
  '\xBADD10',
  '\xCAFE10',
  '2016-06-22 19:10:48-07'::timestamp,
  5,
  '\x4007',
  E'[]',
  '\x2157',
  'STM65w',
  1000,
  1000,
  1000000,
  1000,
  1000,
  1000,
  2000,
  2000
FROM (
  SELECT DISTINCT hafd.operation_id_to_block_num(id) AS block_num
  FROM hafd.operations
) AS ops
ON CONFLICT (block_id) DO NOTHING;

-- Insert missing events for mock data above
INSERT INTO hafd.events_queue(id, event, block_num)
SELECT
  block_num,
  'NEW_IRREVERSIBLE'::hafd.event_type,
  block_num
FROM (
  SELECT DISTINCT hafd.operation_id_to_block_num(id) AS block_num
  FROM hafd.operations
) AS ops
WHERE NOT EXISTS (
  SELECT 1 FROM hafd.events_queue e
  WHERE e.block_num = ops.block_num
);
