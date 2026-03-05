// Smoke test: verify all endpoints respond under minimal load
import http from 'k6/http';
import { check, group } from 'k6';
import { BASE_URL, SAMPLE_CREATORS, SAMPLE_SYMBOLS, SAMPLE_TAGS, SAMPLE_TRX_IDS } from './config.js';

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
    });
  });

  group('Version', () => {
    const res = http.get(`${BASE_URL}/version`);
    check(res, {
      'version returns 200': (r) => r.status === 200,
    });
  });

  group('NFT Types', () => {
    const res = http.get(`${BASE_URL}/nfts`);
    check(res, {
      'nfts returns 200': (r) => r.status === 200,
      'nfts returns array': (r) => Array.isArray(r.json()),
    });
  });

  group('NFT Types with pagination', () => {
    const res = http.get(`${BASE_URL}/nfts?count=10`);
    check(res, {
      'nfts paginated returns 200': (r) => r.status === 200,
    });
  });

  group('NFT Instances', () => {
    const creator = SAMPLE_CREATORS[0];
    const symbol = SAMPLE_SYMBOLS[0];
    const res = http.get(`${BASE_URL}/nfts/${creator}/${symbol}`);
    check(res, {
      'instances returns 200 or 404': (r) => r.status === 200 || r.status === 404,
    });
  });

  group('NFT Instances with tags', () => {
    const creator = SAMPLE_CREATORS[0];
    const symbol = SAMPLE_SYMBOLS[0];
    const tags = SAMPLE_TAGS[0];
    const res = http.get(`${BASE_URL}/nfts/${creator}/${symbol}/${tags}`);
    check(res, {
      'instances with tags returns 200 or 404': (r) => r.status === 200 || r.status === 404,
    });
  });

  group('NFT Instances by transaction', () => {
    const trxId = SAMPLE_TRX_IDS[0];
    const res = http.get(`${BASE_URL}/nfts/by-trx/${trxId}`);
    check(res, {
      'by-trx returns 200': (r) => r.status === 200,
    });
  });
}
