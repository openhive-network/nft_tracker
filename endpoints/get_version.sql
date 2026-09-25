SET ROLE nfttracker_owner;

/** openapi:paths
/version:
  get:
    tags:
      - Other
    summary: Get NFT Tracker''s version
    description: |
      Get NFT Tracker''s last commit hash (versions set by hash value).

      SQL example
      * `SELECT * FROM nfttracker_endpoints.get_version();`
      
      REST call example
      * `GET ''https://%1$s/nft-tracker-api/version''`
    operationId: nfttracker_endpoints.get_version
    responses:
      '200':
        description: |
          NFT Tracker version

          * Returns `TEXT`
        content:
          application/json:
            schema:
              type: string
            example: c2fed8958584511ef1a66dab3dbac8c40f3518f0
      '404':
        description: App not installed
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS nfttracker_endpoints.get_version;
CREATE OR REPLACE FUNCTION nfttracker_endpoints.get_version()
RETURNS TEXT 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE
    _version TEXT;
BEGIN
  -- Set cache headers for version endpoint (doesn't change often)
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=100000"}]', true);

  -- The table is populated at install time by set_version() (see install_app.sh).
  _version := COALESCE((SELECT git_hash FROM nfttracker_app.version LIMIT 1), 'unspecified');

  RETURN _version;
END
$$;

-- Grant execute permission to nfttracker_user
GRANT EXECUTE ON FUNCTION nfttracker_endpoints.get_version() TO nfttracker_user;

RESET ROLE;
