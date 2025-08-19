SET ROLE nfttracker_owner;

CREATE OR REPLACE FUNCTION nfttracker_app.continueProcessing()
RETURNS BOOLEAN
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  RETURN continue_processing FROM nfttracker_app.nfts_app_status LIMIT 1;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.allowProcessing()
RETURNS VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
BEGIN
  UPDATE nfttracker_app.nfts_app_status SET continue_processing = True;
END
$$;

/** Helper function to be called from separate transaction (must be committed)
    to safely stop execution of the application.
**/
CREATE OR REPLACE FUNCTION nfttracker_app.stopProcessing()
RETURNS VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
BEGIN
  UPDATE nfttracker_app.nfts_app_status SET continue_processing = False;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.process_action(
    IN _block_num INT,
    IN _posting_auth hive.account_name_type,
    IN _json JSONB
)
RETURNS SETOF VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
DECLARE
  _symbol nfttracker_app.symbol;
  err_msg TEXT;
  err_detail TEXT;
  err_hint TEXT;
BEGIN
  BEGIN
    IF _json->>'symbol' IS NULL THEN
      RAISE EXCEPTION 'Symbol is not specified';
    END IF;
    RETURN QUERY
      SELECT
        CASE _json->>'action'
          WHEN 'register' THEN nfttracker_app.register(_block_num, _posting_auth, _json)
          WHEN 'modify' THEN nfttracker_app.modify(_block_num, _posting_auth, _json)
          WHEN 'issue' THEN nfttracker_app.issue(_block_num, _posting_auth, _json)
          WHEN 'soulbind' THEN nfttracker_app.soulbind(_block_num, _posting_auth, _json)
          WHEN 'set_data' THEN nfttracker_app.set_data(_block_num, _posting_auth, _json)
          WHEN 'transfer' THEN nfttracker_app.transfer(_block_num, _posting_auth, _json)
        END;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err_msg = MESSAGE_TEXT,
        err_detail = PG_EXCEPTION_DETAIL,
        err_hint = PG_EXCEPTION_HINT;
      RAISE WARNING 'Error processing action % in block %: %', _json->>'action', _block_num, err_msg
        USING DETAIL = err_detail, HINT = err_hint;
  END;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.process_actions(
    IN _block_num INT,
    IN _posting_auth hive.account_name_type,
    IN _json JSONB
)
RETURNS SETOF VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
BEGIN
  IF jsonb_typeof(_json) = 'object' THEN
    RETURN QUERY SELECT nfttracker_app.process_action(_block_num, _posting_auth, _json);
  ELSIF jsonb_typeof(_json) = 'array' THEN
    RETURN QUERY
      SELECT nfttracker_app.process_action(_block_num, _posting_auth, j.v)
      FROM jsonb_array_elements(_json) WITH ORDINALITY AS j(v, idx)
      ORDER BY idx ASC;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.block_range_data(
    IN _first_block_num INT,
    IN _last_block_num INT
)
RETURNS VOID
LANGUAGE 'plpgsql'
VOLATILE
AS $$
DECLARE
  _result INT;
BEGIN
  WITH select_ops AS
  (
    SELECT x.block_num, (x.op).required_posting_auths, (x.op).json::JSONB FROM
    (
      SELECT
        o.block_num,
        o.body_binary::hive.custom_json_operation as op
      FROM hive.operations_view AS o WHERE o.op_type_id = 18
      AND o.block_num BETWEEN _first_block_num AND _last_block_num
    ) AS x
    WHERE (x.op).id = 'NFT'
  ),
  selected_range AS
  (
    SELECT
      o.block_num,
      COALESCE(o.required_posting_auths[1], NULL)::hive.account_name_type AS posting_auth,
      o.json
    FROM select_ops AS o
  ),
  process AS
  (
    SELECT nfttracker_app.process_actions(o.block_num, o.posting_auth, o.json)
    FROM selected_range AS o
  )
  SELECT COUNT(*) FROM process INTO _result;
END
$$;

CREATE OR REPLACE PROCEDURE nfttracker_app.massive_processing(
    IN _from INT, IN _to INT, IN _logs BOOLEAN
)
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __start_ts timestamptz;
  __end_ts   timestamptz;
BEGIN
  PERFORM set_config('synchronous_commit', 'OFF', false);

  IF _logs THEN
    RAISE NOTICE 'nfttracker is attempting to process a block range: <%, %>', _from, _to;
    __start_ts := clock_timestamp();
  END IF;

  PERFORM nfttracker_app.block_range_data(_from, _to);

  IF _logs THEN
    __end_ts := clock_timestamp();
    RAISE NOTICE 'nfttracker processed block range: <%, %> successfully in % s
    ', _from, _to, (extract(epoch FROM __end_ts - __start_ts));
  END IF;
END
$$;

CREATE OR REPLACE PROCEDURE nfttracker_app.single_processing(
    IN _from INT, IN _to INT, IN _logs BOOLEAN
)
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  __start_ts timestamptz;
  __end_ts   timestamptz;
BEGIN
  PERFORM set_config('synchronous_commit', 'ON', false);

  IF _logs THEN
    RAISE NOTICE 'nfttracker processing block: %...', _from;
    __start_ts := clock_timestamp();
  END IF;

  PERFORM nfttracker_app.block_range_data(_from, _to);

  IF _logs THEN
    __end_ts := clock_timestamp();
    RAISE NOTICE 'nfttracker processed block % successfully in % s
    ', _from, (extract(epoch FROM __end_ts - __start_ts));
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.process_blocks(
    _context_name hive.context_name,
    _block_range hive.blocks_range, 
    _logs BOOLEAN = true
)
RETURNS VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
BEGIN
  IF hive.get_current_stage_name(_context_name) = 'MASSIVE_PROCESSING' THEN
    CALL nfttracker_app.massive_processing(_block_range.first_block, _block_range.last_block, _logs);
  ELSE
    CALL nfttracker_app.single_processing(_block_range.first_block, _block_range.last_block, _logs);
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.continueProcessingLoop(
    _appContext hive.context_name,
    _maxBlockLimit INT,
    _blocks_range hive.blocks_range
)
RETURNS BOOLEAN
LANGUAGE 'plpgsql'
AS
$$
BEGIN
    IF _blocks_range IS NULL AND _maxBlockLimit IS NOT NULL THEN
        IF hive.app_get_current_block_num(_appContext) >= _maxBlockLimit THEN
            RAISE NOTICE 'Blocks limit reached. Exiting application main loop at processed block: %.', hive.app_get_current_block_num(_appContext);
            RETURN FALSE;
        END IF;
    END IF;

    IF NOT nfttracker_app.continueProcessing() THEN
        RAISE NOTICE 'Exiting application main loop at processed block: %.', hive.app_get_current_block_num(_appContext);
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END
$$;

/** Application entry point, which:
  - defines its data schema,
  - creates HAF application context,
  - starts application main-loop (which iterates infinitely).
  - To stop it call `nfttracker_app.stopProcessing();` from another session and commit its trasaction.
*/
CREATE OR REPLACE PROCEDURE nfttracker_app.main(
    IN _appContext hive.context_name,
    IN _maxBlockLimit INT = NULL
)
LANGUAGE 'plpgsql'
AS
$$
DECLARE
  _blocks_range hive.blocks_range := (0,0);
BEGIN
  IF _maxBlockLimit != NULL THEN
    RAISE NOTICE 'Max block limit is specified as: %', _maxBlockLimit;
  END IF;

  PERFORM nfttracker_app.allowProcessing();

  RAISE NOTICE 'Last block processed by application: %', hive.app_get_current_block_num(_appContext);
  RAISE NOTICE 'Entering application main loop...';

  LOOP
    CALL hive.app_next_iteration(
      _appContext,
      _blocks_range,
      _override_max_batch => NULL,
      _limit => _maxBlockLimit);

    IF NOT nfttracker_app.continueProcessingLoop( _appContext, _maxBlockLimit, _blocks_range ) THEN
        ROLLBACK;
        RETURN;
    END IF;

    IF _blocks_range IS NULL THEN
      RAISE WARNING 'Waiting for next block...';
      CONTINUE;
    END IF;

    PERFORM nfttracker_app.process_blocks(_appContext, _blocks_range);
  END LOOP;

  ASSERT FALSE, 'Should not reach this point';
END
$$;

RESET ROLE;
