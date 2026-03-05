// Smoke test: verify all endpoints respond under minimal load
import http from 'k6/http';
import { check, group } from 'k6';
import { BASE_URL, CREATOR_SYMBOL_PAIRS, SAMPLE_TAGS, SAMPLE_TRX_IDS } from './config.js';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate==0'],
    http_req_duration: ['p(95)<2000'],
  },
};

export default function () {
  group('OpenAPI spec', () => {
    const res = http.get(`${BASE_URL}/`);
    check(res, {
      'root returns 200': (r) => r.status === 200,
      'root returns JSON': (r) => r.headers['Content-Type']?.includes('application/json'),
      'root contains openapi field': (r) => r.json().openapi !== undefined,
    });
  });

  group('Version', () => {
    const res = http.get(`${BASE_URL}/version`);
    check(res, {
      'version returns 200': (r) => r.status === 200,
      'version is non-empty': (r) => r.body.length > 2,
    });
  });

  group('NFT Types', () => {
    const res = http.get(`${BASE_URL}/nfts`);
    check(res, {
      'nfts returns 200': (r) => r.status === 200,
      'nfts returns non-empty array': (r) => {
        const data = r.json();
        return Array.isArray(data) && data.length > 0;
      },
    });
  });

  group('NFT Types with pagination', () => {
    const res = http.get(`${BASE_URL}/nfts?count=1`);
    check(res, {
      'nfts paginated returns 200': (r) => r.status === 200,
      'nfts paginated respects count': (r) => r.json().length <= 1,
    });
  });

  group('NFT Instances', () => {
    const pair = CREATOR_SYMBOL_PAIRS[0];
    const res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}`);
    check(res, {
      'instances returns 200': (r) => r.status === 200,
      'instances returns non-empty array': (r) => {
        const data = r.json();
        return Array.isArray(data) && data.length > 0;
      },
    });
  });

  group('NFT Instances with pagination', () => {
    const pair = CREATOR_SYMBOL_PAIRS[0];
    const res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}?count=2`);
    check(res, {
      'instances paginated returns 200': (r) => r.status === 200,
      'instances paginated respects count': (r) => r.json().length <= 2,
    });
  });

  group('NFT Instances with tags', () => {
    const pair = CREATOR_SYMBOL_PAIRS[0];
    const tags = SAMPLE_TAGS[0];
    const res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}/${tags}`);
    check(res, {
      'instances with tags returns 200': (r) => r.status === 200,
      'instances with tags returns array': (r) => Array.isArray(r.json()),
    });
  });

  group('NFT Instances by transaction', () => {
    const trxId = SAMPLE_TRX_IDS[0];
    const res = http.get(`${BASE_URL}/nfts/by-trx/${trxId}`);
    check(res, {
      'by-trx returns 200': (r) => r.status === 200,
      'by-trx returns array': (r) => Array.isArray(r.json()),
    });
  });
}
