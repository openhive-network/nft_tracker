// Stress test: push the API beyond normal load to find breaking points
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, SAMPLE_CREATORS, SAMPLE_SYMBOLS, SAMPLE_TAGS, SAMPLE_TRX_IDS } from './config.js';

const MAX_VUS = parseInt(__ENV.MAX_VUS || '50');

export const options = {
  stages: [
    { duration: '30s', target: Math.floor(MAX_VUS * 0.2) },  // warm up
    { duration: '1m',  target: Math.floor(MAX_VUS * 0.5) },  // moderate load
    { duration: '1m',  target: MAX_VUS },                     // peak load
    { duration: '1m',  target: MAX_VUS },                     // sustain peak
    { duration: '30s', target: 0 },                           // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    http_req_failed: ['rate<0.05'],
  },
};

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// Weighted endpoint selection simulating realistic traffic patterns
const ENDPOINTS = [
  { weight: 30, fn: getTypes },
  { weight: 25, fn: getInstances },
  { weight: 15, fn: getInstancesWithTags },
  { weight: 15, fn: getInstancesByTrx },
  { weight: 10, fn: getTypesPaginated },
  { weight: 5,  fn: getVersion },
];

const WEIGHTED = [];
for (const ep of ENDPOINTS) {
  for (let i = 0; i < ep.weight; i++) {
    WEIGHTED.push(ep.fn);
  }
}

function getVersion() {
  return http.get(`${BASE_URL}/version`);
}

function getTypes() {
  return http.get(`${BASE_URL}/nfts`);
}

function getTypesPaginated() {
  const count = Math.floor(Math.random() * 100) + 1;
  return http.get(`${BASE_URL}/nfts?count=${count}`);
}

function getInstances() {
  const creator = randomItem(SAMPLE_CREATORS);
  const symbol = randomItem(SAMPLE_SYMBOLS);
  return http.get(`${BASE_URL}/nfts/${creator}/${symbol}`);
}

function getInstancesWithTags() {
  const creator = randomItem(SAMPLE_CREATORS);
  const symbol = randomItem(SAMPLE_SYMBOLS);
  const tags = randomItem(SAMPLE_TAGS);
  return http.get(`${BASE_URL}/nfts/${creator}/${symbol}/${tags}`);
}

function getInstancesByTrx() {
  const trxId = randomItem(SAMPLE_TRX_IDS);
  return http.get(`${BASE_URL}/nfts/by-trx/${trxId}`);
}

export default function () {
  const endpoint = WEIGHTED[Math.floor(Math.random() * WEIGHTED.length)];
  const res = endpoint();
  check(res, {
    'not server error': (r) => r.status < 500,
  });
  sleep(0.1 + Math.random() * 0.4);
}
