-- Every function in nfttracker_endpoints, the schema PostgREST exposes, is
-- STABLE or IMMUTABLE, so PostgREST runs it in a READ ONLY transaction even
-- when it is called by POST. Then root() is called as nfttracker_user inside a
-- READ ONLY transaction.
-- Runs as haf_admin after each install (.aidev/run-checks.sh check_installed)
-- and writes nothing.
\set ON_ERROR_STOP on

DO $$
DECLARE
  _volatile TEXT;
BEGIN
  SELECT string_agg(p.oid::regprocedure::TEXT, ', ' ORDER BY p.proname)
  INTO _volatile
  FROM pg_proc p
  WHERE p.pronamespace = 'nfttracker_endpoints'::regnamespace
    AND p.provolatile = 'v';

  IF _volatile IS NOT NULL THEN
    RAISE EXCEPTION 'nfttracker_endpoints functions declared VOLATILE: %', _volatile;
  END IF;

  RAISE NOTICE 'every function in nfttracker_endpoints is STABLE or IMMUTABLE';
END
$$;

BEGIN READ ONLY;
SET LOCAL ROLE nfttracker_user;

DO $$
BEGIN
  IF current_setting('transaction_read_only') <> 'on' THEN
    RAISE EXCEPTION 'the endpoint calls are not running in a READ ONLY transaction';
  END IF;

  PERFORM nfttracker_endpoints.root();

  RAISE NOTICE 'root() runs as nfttracker_user in a READ ONLY transaction';
END
$$;

ROLLBACK;
