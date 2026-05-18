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

CREATE OR REPLACE FUNCTION nfttracker_app.record_operation_result(
    IN _operation_id BIGINT,
    IN _block_num INT,
    IN _subsequent_no BIGINT,
    IN _action TEXT,
    IN _symbol TEXT,
    IN _account hafd.account_name_type,
    IN _success BOOLEAN,
    IN _error_message TEXT
)
RETURNS VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
BEGIN
  INSERT INTO nfttracker_app.operation_results
    (operation_id, op_pos, subsequent_no, action, symbol, account, success, error_message, created_at)
  SELECT _operation_id, o.op_pos, _subsequent_no, _action,
         _symbol, _account, _success, _error_message, b.created_at
  FROM hive.blocks_view AS b
  JOIN hafd.operations o ON o.id = _operation_id
  WHERE b.num = _block_num;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to record operation result for block % (op=%, action=%, symbol=%): %',
      _block_num, _operation_id, _action, _symbol, SQLERRM;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.process_action(
    IN _block_num INT,
    IN _active_auth hafd.account_name_type,
    IN _json JSONB,
    IN _operation_id BIGINT,
    IN _subsequent_no BIGINT
)
RETURNS SETOF VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
DECLARE
  _symbol nfttracker_app.symbol;
  _action TEXT;
  err_msg TEXT;
  err_detail TEXT;
  err_hint TEXT;
BEGIN
  _action := _json->>'action';
  IF _action IS NULL THEN
    RAISE WARNING 'Error processing operation in block %: Action is not specified', _block_num;
    RETURN;
  END IF;
  IF _json->>'symbol' IS NULL THEN
    RAISE WARNING 'Error processing action % in block %: Symbol is not specified', _action, _block_num;
    RETURN;
  END IF;
  IF _active_auth IS NULL THEN
    RAISE WARNING 'Error processing action % in block %: Active authority is required', _action, _block_num;
    PERFORM nfttracker_app.record_operation_result(
      _operation_id, _block_num, _subsequent_no, _action,
      _json->>'symbol', NULL, FALSE, 'Active authority is required');
    RETURN;
  END IF;
  BEGIN
    RETURN QUERY
      SELECT
        CASE _action
          WHEN 'register' THEN nfttracker_app.register(_block_num, _active_auth, _json)
          WHEN 'modify' THEN nfttracker_app.modify(_block_num, _active_auth, _json)
          WHEN 'issue' THEN nfttracker_app.issue(_block_num, _active_auth, _json, _operation_id, _subsequent_no)
          WHEN 'soulbind' THEN nfttracker_app.soulbind(_block_num, _active_auth, _json)
          WHEN 'set_data' THEN nfttracker_app.set_data(_block_num, _active_auth, _json)
          WHEN 'update_tags' THEN nfttracker_app.update_tags(_block_num, _active_auth, _json)
          WHEN 'transfer' THEN nfttracker_app.transfer(_block_num, _active_auth, _json)
        END;

    PERFORM nfttracker_app.record_operation_result(
      _operation_id, _block_num, _subsequent_no, _action,
      _json->>'symbol', _active_auth, TRUE, NULL);

  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err_msg = MESSAGE_TEXT,
        err_detail = PG_EXCEPTION_DETAIL,
        err_hint = PG_EXCEPTION_HINT;
      RAISE WARNING 'Error processing action % in block %: %', _action, _block_num, err_msg
        USING DETAIL = err_detail, HINT = err_hint;

      PERFORM nfttracker_app.record_operation_result(
        _operation_id, _block_num, _subsequent_no, _action,
        _json->>'symbol', _active_auth, FALSE, err_msg);
  END;
END
$$;

CREATE OR REPLACE FUNCTION nfttracker_app.process_actions(
    IN _block_num INT,
    IN _active_auth hafd.account_name_type,
    IN _json JSONB,
    IN _operation_id BIGINT
)
RETURNS SETOF VOID
LANGUAGE 'plpgsql' VOLATILE
AS
$$
BEGIN
  IF jsonb_typeof(_json) = 'object' THEN
    RETURN QUERY SELECT nfttracker_app.process_action(_block_num, _active_auth, _json, _operation_id, 0::BIGINT);
  ELSIF jsonb_typeof(_json) = 'array' THEN
    RETURN QUERY
      SELECT nfttracker_app.process_action(_block_num, _active_auth, j.v, _operation_id, (j.idx - 1)::BIGINT)
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
    SELECT x.block_num, x.operation_id, (x.op).required_auths, (x.op).json::JSONB FROM
    (
      SELECT
        o.block_num,
        o.id AS operation_id,
        jsonb_populate_record(NULL::hive.custom_json_operation, o.body_value) as op
      FROM hive.operations_view AS o
      WHERE o.op_type_id = nfttracker_backend.op_custom_json()
      AND o.custom_json_type_id = nfttracker_backend.custom_json_nft_type_id()
      AND o.block_num BETWEEN _first_block_num AND _last_block_num
    ) AS x
  ),
  selected_range AS
  (
    SELECT
      o.block_num,
      o.operation_id,
      COALESCE(o.required_auths[1], NULL)::hafd.account_name_type AS active_auth,
      o.json
    FROM select_ops AS o
  ),
  process AS
  (
    SELECT nfttracker_app.process_actions(o.block_num, o.active_auth, o.json, o.operation_id)
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
  _was_idle BOOLEAN := FALSE;
BEGIN
  IF _maxBlockLimit != NULL THEN
    RAISE NOTICE 'Max block limit is specified as: %', _maxBlockLimit;
  END IF;

  PERFORM nfttracker_app.allowProcessing();

  -- Register partial index on hafd.operations for NFT custom_json ops.
  -- HAF's indexes_controler creates it concurrently when appropriate.
  -- No-op if 'NFT' type doesn't exist yet (first sync from genesis).
  PERFORM nfttracker_app.register_nft_index();

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
      IF NOT _was_idle THEN
        RAISE NOTICE 'Waiting for next block...';
        _was_idle := TRUE;
      END IF;
      CONTINUE;
    END IF;

    _was_idle := FALSE;
    PERFORM nfttracker_app.process_blocks(_appContext, _blocks_range);
  END LOOP;

  ASSERT FALSE, 'Should not reach this point';
END
$$;

RESET ROLE;
