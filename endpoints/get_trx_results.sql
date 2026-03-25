SET ROLE nfttracker_owner;

/** openapi:paths
/trx/{trx_id}/results:
  get:
    tags:
      - NFT
    summary: Transaction results
    description: |
      Returns the results of NFT operations in a given transaction,
      including both successes and failures with error messages.

      SQL example
      * `SELECT * FROM nfttracker_endpoints.get_trx_results(''abc123...'');`

      REST call example
      * `GET ''https://%1$s/nft-tracker-api/trx/abc123.../results''`
    operationId: nfttracker_endpoints.get_trx_results
    parameters:
      - in: path
        name: trx_id
        required: true
        schema:
          type: string
        description: hex-encoded transaction hash (40 characters)
      - in: query
        name: count
        required: false
        schema:
          type: integer
          default: NULL
        description: |
          Maximum number of results to return. The value is capped at 1000, which is also the default.
      - in: query
        name: last_id
        required: false
        schema:
          type: integer
          default: NULL
        description: |
          Return results with IDs greater than this value.
    responses:
      '200':
        description: |
          Operation results for the given transaction

          * Returns `nfttracker_endpoints.trx_result`
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/nfttracker_endpoints.trx_result'
            example: [{
              "id": 1,
              "action": "register",
              "symbol": "alice/CARD",
              "account": "alice",
              "success": true,
              "error_message": null,
              "created_at": "2025-08-22T12:00:00"
            }]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS nfttracker_endpoints.get_trx_results;
CREATE OR REPLACE FUNCTION nfttracker_endpoints.get_trx_results(
    "trx_id" TEXT,
    "count" INT = NULL,
    "last_id" BIGINT = NULL
)
RETURNS nfttracker_endpoints.trx_result[]
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN nfttracker_backend.get_trx_results(trx_id, "count", last_id);
END
$$;

RESET ROLE;
