// Load test: sustained traffic across all endpoints
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { BASE_URL, SAMPLE_CREATORS, SAMPLE_SYMBOLS, SAMPLE_TAGS, SAMPLE_TRX_IDS, DEFAULT_THRESHOLDS } from './config.js';

const DURATION = __ENV.DURATION || '2m';
const VUS = parseInt(__ENV.VUS || '10');

export const options = {
  stages: [
    { duration: '30s', target: VUS },       // ramp up
    { duration: DURATION, target: VUS },     // sustained load
    { duration: '15s', target: 0 },          // ramp down
  ],
  thresholds: DEFAULT_THRESHOLDS,
};

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function () {
  group('Version', () => {
    const res = http.get(`${BASE_URL}/version`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Types', () => {
    const res = http.get(`${BASE_URL}/nfts`);
    check(res, {
      'status 200': (r) => r.status === 200,
      'returns array': (r) => Array.isArray(r.json()),
    });
  });

  group('NFT Types paginated', () => {
    const count = Math.floor(Math.random() * 50) + 1;
    const res = http.get(`${BASE_URL}/nfts?count=${count}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Instances', () => {
    const creator = randomItem(SAMPLE_CREATORS);
    const symbol = randomItem(SAMPLE_SYMBOLS);
    const res = http.get(`${BASE_URL}/nfts/${creator}/${symbol}`);
    check(res, { 'status 200 or 404': (r) => r.status === 200 || r.status === 404 });
  });

  group('NFT Instances with holder', () => {
    const creator = randomItem(SAMPLE_CREATORS);
    const symbol = randomItem(SAMPLE_SYMBOLS);
    const holder = randomItem(SAMPLE_CREATORS);
    const res = http.get(`${BASE_URL}/nfts/${creator}/${symbol}?holder=${holder}`);
    check(res, { 'status 200 or 404': (r) => r.status === 200 || r.status === 404 });
  });

  group('NFT Instances with tags', () => {
    const creator = randomItem(SAMPLE_CREATORS);
    const symbol = randomItem(SAMPLE_SYMBOLS);
    const tags = randomItem(SAMPLE_TAGS);
    const res = http.get(`${BASE_URL}/nfts/${creator}/${symbol}/${tags}`);
    check(res, { 'status 200 or 404': (r) => r.status === 200 || r.status === 404 });
  });

  group('NFT Instances by transaction', () => {
    const trxId = randomItem(SAMPLE_TRX_IDS);
    const res = http.get(`${BASE_URL}/nfts/by-trx/${trxId}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  sleep(0.5);
}
