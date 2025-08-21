SET ROLE nfttracker_owner;

/** openapi
openapi: 3.1.0
info:
  title: NFT Tracker
  description: >-
    NFT Tracker is an API for managing and tracking NFTs on the Hive blockchain
  license:
    name: MIT License
    url: https://opensource.org/license/mit
  version: 0.1.0
externalDocs:
  description: NFT Tracker gitlab repository
  url: https://gitlab.syncad.com/hive/nft_tracker
tags:
  - name: NFT
    description: NFT management operations
  - name: Other
    description: General API information
servers:
  - url: /nft-tracker-api
 */

DO $__$
    DECLARE
        __schema_name VARCHAR;
        __swagger_url TEXT;
    BEGIN
        SHOW SEARCH_PATH INTO __schema_name;
        __swagger_url := current_setting('custom.swagger_url', true)::TEXT;
        IF __swagger_url IS NULL THEN
            __swagger_url := 'localhost';
        END IF;

        CREATE SCHEMA IF NOT EXISTS nfttracker_endpoints AUTHORIZATION nfttracker_owner;

        EXECUTE FORMAT(
                'create or replace function nfttracker_endpoints.root() returns json as $_$
                declare
                -- openapi-spec
-- openapi-generated-code-begin
  openapi json = $$
{
  "openapi": "3.1.0",
  "info": {
    "title": "NFT Tracker",
    "description": "NFT Tracker is an API for managing and tracking NFTs on the Hive blockchain",
    "license": {
      "name": "MIT License",
      "url": "https://opensource.org/license/mit"
    },
    "version": "0.1.0"
  },
  "externalDocs": {
    "description": "NFT Tracker gitlab repository",
    "url": "https://gitlab.syncad.com/hive/nft_tracker"
  },
  "tags": [
    {
      "name": "NFT",
      "description": "NFT management operations"
    },
    {
      "name": "Other",
      "description": "General API information"
    }
  ],
  "servers": [
    {
      "url": "/nft-tracker-api"
    }
  ],
  "paths": {
    "/version": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "Get NFT Tracker''s version",
        "description": "Get NFT Tracker''s last commit hash (versions set by hash value).\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_version();`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/version''`\n",
        "operationId": "nfttracker_endpoints.get_version",
        "responses": {
          "200": {
            "description": "NFT Tracker version\n\n* Returns `TEXT`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string"
                },
                "example": "c2fed8958584511ef1a66dab3dbac8c40f3518f0"
              }
            }
          },
          "404": {
            "description": "App not installed"
          }
        }
      }
    }
  }
}
$$;
-- openapi-generated-code-end
begin
  return openapi;
end
$_$ language plpgsql;'
            , __swagger_url);

        -- Grant execute permission on the root function to nfttracker_user
        GRANT EXECUTE ON FUNCTION nfttracker_endpoints.root() TO nfttracker_user;

    END
$__$;

RESET ROLE;