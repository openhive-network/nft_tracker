BEGIN;
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
    (1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (2, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (3, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (4, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (5, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:33-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (6, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:36-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (7, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:39-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (8, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:42-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000),
    (9, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:45-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000);
  INSERT INTO hafd.accounts(id, name, block_num) VALUES
    (1, 'null', 1),
    (5, 'initminer', 1),
    (6, 'alice', 1),
    (7, 'bob', 1),
    (8, 'charlie', 1),
    (9, 'dan', 1);
COMMIT;
