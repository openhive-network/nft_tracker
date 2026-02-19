BEGIN;
  GRANT SELECT ON hafd.accounts TO nfttracker_owner;
  GRANT REFERENCES ON hafd.accounts TO nfttracker_owner;

  INSERT INTO hafd.events_queue VALUES
    (0, 'NEW_IRREVERSIBLE', 0),
    (1, 'NEW_IRREVERSIBLE', 1),
    (2, 'NEW_IRREVERSIBLE', 2),
    (3, 'NEW_IRREVERSIBLE', 3),
    (4, 'NEW_IRREVERSIBLE', 4),
    (5, 'NEW_IRREVERSIBLE', 5),
    (6, 'NEW_IRREVERSIBLE', 6),
    (7, 'NEW_IRREVERSIBLE', 7),
    (8, 'NEW_IRREVERSIBLE', 8),
    (9, 'NEW_IRREVERSIBLE', 9);
  INSERT INTO hafd.fork VALUES (1, 1, now());
  INSERT INTO hafd.blocks VALUES
    (hafd.make_block_id(1, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(2, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(3, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(4, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(5, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:33-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(6, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:36-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(7, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:39-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(8, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:42-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (hafd.make_block_id(9, 1), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:45-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000);
  INSERT INTO hafd.operation_types(id, name, is_virtual)
    VALUES (18, 'hive::protocol::custom_json_operation', FALSE);
  INSERT INTO hafd.custom_json_types(custom_json_id) VALUES ('NFT');
  INSERT INTO hafd.accounts(id, name, block_id) VALUES
    (1, 'null', hafd.make_block_id(1, 1)),
    (5, 'initminer', hafd.make_block_id(1, 1)),
    (6, 'alice', hafd.make_block_id(1, 1)),
    (7, 'bob', hafd.make_block_id(1, 1)),
    (8, 'charlie', hafd.make_block_id(1, 1)),
    (9, 'dan', hafd.make_block_id(1, 1));
COMMIT;
