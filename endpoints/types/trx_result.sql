/** openapi:components:schemas
nfttracker_endpoints.trx_result:
  type: object
  properties:
    id:
      type: integer
      description: unique result ID
    action:
      type: string
      description: NFT action type (register, issue, transfer, etc.)
    symbol:
      type: string
      description: NFT symbol targeted by the operation (e.g. alice/CARD)
    account:
      type: string
      description: account that submitted the operation
    success:
      type: boolean
      description: whether the operation succeeded
    error_message:
      type: string
      description: error message if the operation failed, null on success
    created_at:
      type: string
      format: date-time
      description: block timestamp when the operation was processed
*/
-- openapi-generated-code-begin
DROP TYPE IF EXISTS nfttracker_endpoints.trx_result CASCADE;
CREATE TYPE nfttracker_endpoints.trx_result AS (
    "id" BIGINT,
    "action" TEXT,
    "symbol" TEXT,
    "account" TEXT,
    "success" BOOLEAN,
    "error_message" TEXT,
    "created_at" TIMESTAMP
);
-- openapi-generated-code-end
