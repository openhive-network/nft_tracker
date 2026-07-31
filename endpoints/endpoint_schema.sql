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
  version: 0.0.0-dev
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
        CREATE SCHEMA IF NOT EXISTS nfttracker_backend AUTHORIZATION nfttracker_owner;

        EXECUTE FORMAT(
                'create or replace function nfttracker_endpoints.root() returns json as $_$
                declare
                -- openapi-spec
-- openapi-generated-code-begin
  openapi json = $$
{
  "components": {
    "schemas": {
      "nfttracker_endpoints.nft_type": {
        "type": "object",
        "properties": {
          "id": {
            "type": "integer",
            "description": "id of NFT type"
          },
          "creator": {
            "type": "string",
            "description": "account name that registered NFT type"
          },
          "owner": {
            "type": "string",
            "description": "current owner of NFT type"
          },
          "symbol": {
            "type": "string",
            "description": "symbol name of registered NFT type"
          },
          "name": {
            "type": "string",
            "description": "name of registered NFT type"
          },
          "max_count": {
            "type": "integer",
            "description": "max number of possible issued instances of this NFT type"
          },
          "created_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp when the NFT type was registered"
          },
          "updated_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp when the NFT type was last modified"
          },
          "authorized_issuers": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "list of accounts that can issue instance of this NFT type"
          }
        }
      },
      "nfttracker_endpoints.nft_instance": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "description": "id of NFT instance"
          },
          "holder": {
            "type": "string",
            "description": "account currently owning this instance"
          },
          "data": {
            "type": "string",
            "description": "extra data as JSON"
          },
          "tags": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "extra tags associated with this instance"
          },
          "soulbound": {
            "type": "boolean",
            "description": "whether this instance is soulbound (cannot be transferred to other account)"
          },
          "created_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp when this instance was created"
          },
          "updated_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp this instance was last modified"
          }
        }
      },
      "nfttracker_endpoints.nft_instance_with_type": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "description": "id of NFT instance"
          },
          "creator": {
            "type": "string",
            "description": "account that registered the NFT type"
          },
          "symbol": {
            "type": "string",
            "description": "symbol name of the NFT type"
          },
          "holder": {
            "type": "string",
            "description": "account currently owning this instance"
          },
          "data": {
            "type": "string",
            "description": "extra data as JSON"
          },
          "tags": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "description": "extra tags associated with this instance"
          },
          "soulbound": {
            "type": "boolean",
            "description": "whether this instance is soulbound (cannot be transferred to other account)"
          },
          "created_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp when this instance was created"
          },
          "updated_at": {
            "type": "string",
            "format": "date-time",
            "description": "the timestamp this instance was last modified"
          }
        }
      },
      "nfttracker_endpoints.trx_result": {
        "type": "object",
        "properties": {
          "id": {
            "type": "integer",
            "description": "unique result ID"
          },
          "op_pos": {
            "type": "integer",
            "description": "position of the operation within the block"
          },
          "subsequent_no": {
            "type": "integer",
            "description": "0-based position of this action within the transaction''s action array"
          },
          "action": {
            "type": "string",
            "description": "NFT action type (register, issue, transfer, etc.)"
          },
          "symbol": {
            "type": "string",
            "description": "NFT symbol targeted by the operation (e.g. alice/CARD)"
          },
          "account": {
            "type": "string",
            "nullable": true,
            "description": "account that submitted the operation, null for malformed operations lacking active authority"
          },
          "success": {
            "type": "boolean",
            "description": "whether the operation succeeded"
          },
          "error_message": {
            "type": "string",
            "description": "error message if the operation failed, null on success"
          },
          "created_at": {
            "type": "string",
            "format": "date-time",
            "description": "block timestamp when the operation was processed"
          }
        }
      }
    }
  },
  "openapi": "3.1.0",
  "info": {
    "title": "NFT Tracker",
    "description": "NFT Tracker is an API for managing and tracking NFTs on the Hive blockchain",
    "license": {
      "name": "MIT License",
      "url": "https://opensource.org/license/mit"
    },
    "version": "0.0.0-dev"
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
    },
    "/sync-status": {
      "get": {
        "tags": [
          "Other"
        ],
        "summary": "Get NFT Tracker''s sync status",
        "description": "Get the last block processed by NFT Tracker as an object containing\nboth the block number and its timestamp (UTC). This is the uniform\nHAF-app sync/health endpoint: the timestamp lets a consumer compute\nstaleness with a single call (`age = now() - last_block_time`) without\nneeding a separate head-block reference.\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_sync_status();`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/sync-status''`\n",
        "operationId": "nfttracker_endpoints.get_sync_status",
        "responses": {
          "200": {
            "description": "Last block processed by NFT Tracker and its timestamp.\n`last_block_time` is null if no block has been processed yet.\nWhile the HAF instance is still in massive sync (indexes not yet\nbuilt) the call fails fast with an error rather than executing an\nunindexed lookup.\n\n* Returns `JSON`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "x-sql-datatype": "JSON",
                  "properties": {
                    "last_block_num": {
                      "type": "integer",
                      "description": "highest block number processed by the app"
                    },
                    "last_block_time": {
                      "type": "string",
                      "format": "date-time",
                      "description": "UTC timestamp of that block"
                    }
                  }
                },
                "example": {
                  "last_block_num": 5000000,
                  "last_block_time": "2016-09-15T19:47:21"
                }
              }
            }
          }
        }
      }
    },
    "/nfts": {
      "get": {
        "tags": [
          "NFT"
        ],
        "summary": "NFT types",
        "description": "Returns registered NFT types.\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_nft_types();`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/nfts''`\n",
        "operationId": "nfttracker_endpoints.get_nft_types",
        "parameters": [
          {
            "in": "query",
            "name": "count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Maximum number of types to return. The value is capped at 1000, which is also the default.\n"
          },
          {
            "in": "query",
            "name": "last_id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Return types with IDs greater than this value.\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Registered NFT types\n\n* Returns `nfttracker_endpoints.nft_type`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/nfttracker_endpoints.nft_type"
                  }
                },
                "example": [
                  {
                    "id": 1,
                    "creator": "alice",
                    "owner": "bob",
                    "symbol": "TEST",
                    "name": "Test symbol",
                    "max_count": 10,
                    "created_at": "2025-08-22T12:00:00",
                    "updated_at": "2025-08-22T12:00:00",
                    "authorized_issuers": [
                      "alice",
                      "bob"
                    ]
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/nfts/{creator}/{symbol}": {
      "get": {
        "tags": [
          "NFT"
        ],
        "summary": "NFT instances",
        "description": "Returns issued instances of given NFT symbol.\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_nft_instances(''alice'', ''TEST'');`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/nfts/alice/TEST''`\n",
        "operationId": "nfttracker_endpoints.get_nft_instances",
        "parameters": [
          {
            "in": "path",
            "name": "creator",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "name of the account that created the NFT type"
          },
          {
            "in": "path",
            "name": "symbol",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "NFT symbol"
          },
          {
            "in": "query",
            "name": "holder",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Only return instances held by this account\n"
          },
          {
            "in": "query",
            "name": "count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Maximum number of instances to return. The value is capped at 1000, which is also the default\n"
          },
          {
            "in": "query",
            "name": "last_id",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Return instances with IDs greater than this value\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Issued NFT instances of given symbol\n\n* Returns `nfttracker_endpoints.nft_instance`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/nfttracker_endpoints.nft_instance"
                  }
                },
                "example": [
                  {
                    "id": "123456789012345678",
                    "holder": "alice",
                    "data": "{\"key\": \"value\"}",
                    "tags": [
                      "item",
                      "collectible"
                    ],
                    "soulbound": false,
                    "created_at": "2025-08-22T12:00:00",
                    "updated_at": "2025-08-22T12:00:00"
                  }
                ]
              }
            }
          },
          "404": {
            "description": "creator/symbol combination does not exist\n"
          }
        }
      }
    },
    "/nfts/{creator}/{symbol}/{tags}": {
      "get": {
        "tags": [
          "NFT"
        ],
        "summary": "NFT instances",
        "description": "Returns issued instances of given NFT symbol.\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_nft_instances(''alice'', ''TEST'');`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/nfts/alice/TEST''`\n",
        "operationId": "nfttracker_endpoints.get_nft_instances_with_tags",
        "parameters": [
          {
            "in": "path",
            "name": "creator",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "name of the account that created the NFT type"
          },
          {
            "in": "path",
            "name": "symbol",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "NFT symbol"
          },
          {
            "in": "path",
            "name": "tags",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "Only return instances with tags matching pattern.\nPattern is a pipe-separated list of comma-separated tags.\nExample: `a,b|x,y|z` will match instances with tags ''a'' and ''b'', ''x'' and ''y'', or ''z''.\n"
          },
          {
            "in": "query",
            "name": "holder",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Only return instances held by this account\n"
          },
          {
            "in": "query",
            "name": "count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Maximum number of instances to return. The value is capped at 1000, which is also the default.\n"
          },
          {
            "in": "query",
            "name": "last_id",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Return instances with IDs greater than this value.\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Issued NFT instances of given symbol\n\n* Returns `nfttracker_endpoints.nft_instance`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/nfttracker_endpoints.nft_instance"
                  }
                },
                "example": [
                  {
                    "id": "123456789012345678",
                    "holder": "alice",
                    "data": "{\"key\": \"value\"}",
                    "tags": [
                      "item",
                      "collectible"
                    ],
                    "soulbound": false,
                    "created_at": "2025-08-22T12:00:00",
                    "updated_at": "2025-08-22T12:00:00"
                  }
                ]
              }
            }
          },
          "404": {
            "description": "creator/symbol combination does not exist\n"
          }
        }
      }
    },
    "/nfts/by-trx/{trx_id}": {
      "get": {
        "tags": [
          "NFT"
        ],
        "summary": "NFT instances by transaction",
        "description": "Returns NFT instances created by a given transaction.\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_nft_instances_by_trx(''abc123...'');`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/nfts/by-trx/abc123...''`\n",
        "operationId": "nfttracker_endpoints.get_nft_instances_by_trx",
        "parameters": [
          {
            "in": "path",
            "name": "trx_id",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "hex-encoded transaction hash"
          },
          {
            "in": "query",
            "name": "count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Maximum number of instances to return. The value is capped at 1000, which is also the default.\n"
          },
          {
            "in": "query",
            "name": "last_id",
            "required": false,
            "schema": {
              "type": "string",
              "default": null
            },
            "description": "Return instances with IDs greater than this value.\n"
          }
        ],
        "responses": {
          "200": {
            "description": "NFT instances created by the given transaction\n\n* Returns `nfttracker_endpoints.nft_instance_with_type`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/nfttracker_endpoints.nft_instance_with_type"
                  }
                },
                "example": [
                  {
                    "id": "123456789012345678",
                    "creator": "alice",
                    "symbol": "TEST",
                    "holder": "bob",
                    "data": "{\"key\": \"value\"}",
                    "tags": [
                      "item",
                      "collectible"
                    ],
                    "soulbound": false,
                    "created_at": "2025-08-22T12:00:00",
                    "updated_at": "2025-08-22T12:00:00"
                  }
                ]
              }
            }
          }
        }
      }
    },
    "/trx/{trx_id}/results": {
      "get": {
        "tags": [
          "NFT"
        ],
        "summary": "Transaction results",
        "description": "Returns the results of NFT operations in a given transaction,\nincluding both successes and failures with error messages.\n\nSQL example\n* `SELECT * FROM nfttracker_endpoints.get_trx_results(''abc123...'');`\n\nREST call example\n* `GET ''https://%1$s/nft-tracker-api/trx/abc123.../results''`\n",
        "operationId": "nfttracker_endpoints.get_trx_results",
        "parameters": [
          {
            "in": "path",
            "name": "trx_id",
            "required": true,
            "schema": {
              "type": "string"
            },
            "description": "hex-encoded transaction hash (40 characters)"
          },
          {
            "in": "query",
            "name": "count",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Maximum number of results to return. The value is capped at 1000, which is also the default.\n"
          },
          {
            "in": "query",
            "name": "last_id",
            "required": false,
            "schema": {
              "type": "integer",
              "default": null
            },
            "description": "Return results with IDs greater than this value.\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Operation results for the given transaction\n\n* Returns `nfttracker_endpoints.trx_result`\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/nfttracker_endpoints.trx_result"
                  }
                },
                "example": [
                  {
                    "id": 1,
                    "op_pos": 0,
                    "subsequent_no": 0,
                    "action": "register",
                    "symbol": "alice/CARD",
                    "account": "alice",
                    "success": true,
                    "error_message": null,
                    "created_at": "2025-08-22T12:00:00"
                  }
                ]
              }
            }
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
