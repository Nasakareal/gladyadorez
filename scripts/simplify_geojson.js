const fs = require('fs');
const path = require('path');

const source = path.resolve(__dirname, '..', 'assets', 'geo', 'michoacan.json');
const target = path.resolve(
  __dirname,
  '..',
  'assets',
  'geo',
  'michoacan_simplified.json',
);

const tolerance = Number(process.argv[2] || 0.0015);
const sqTolerance = tolerance * tolerance;

function sqDistance(a, b) {
  const dx = a[0] - b[0];
  const dy = a[1] - b[1];
  return dx * dx + dy * dy;
}

function sqSegmentDistance(point, start, end) {
  let x = start[0];
  let y = start[1];
  let dx = end[0] - x;
  let dy = end[1] - y;

  if (dx !== 0 || dy !== 0) {
    const t = ((point[0] - x) * dx + (point[1] - y) * dy) / (dx * dx + dy * dy);
    if (t > 1) {
      x = end[0];
      y = end[1];
    } else if (t > 0) {
      x += dx * t;
      y += dy * t;
    }
  }

  dx = point[0] - x;
  dy = point[1] - y;
  return dx * dx + dy * dy;
}

function simplifyStep(points, first, last, out) {
  let maxDistance = sqTolerance;
  let index = -1;
  for (let i = first + 1; i < last; i += 1) {
    const distance = sqSegmentDistance(points[i], points[first], points[last]);
    if (distance > maxDistance) {
      index = i;
      maxDistance = distance;
    }
  }
  if (index < 0) return;
  if (index - first > 1) simplifyStep(points, first, index, out);
  out.push(points[index]);
  if (last - index > 1) simplifyStep(points, index, last, out);
}

function simplifyRing(ring) {
  if (!Array.isArray(ring) || ring.length <= 8) return ring;
  const closed = sqDistance(ring[0], ring[ring.length - 1]) === 0;
  const points = closed ? ring.slice(0, -1) : ring.slice();
  if (points.length <= 4) return ring;
  const out = [points[0]];
  simplifyStep(points, 0, points.length - 1, out);
  out.push(points[points.length - 1]);
  if (closed) out.push(out[0]);
  return out.length >= 4 ? out : ring;
}

function simplifyGeometry(geometry) {
  if (!geometry || !Array.isArray(geometry.coordinates)) return;
  if (geometry.type === 'Polygon') {
    geometry.coordinates = geometry.coordinates.map(simplifyRing);
  } else if (geometry.type === 'MultiPolygon') {
    geometry.coordinates = geometry.coordinates.map((polygon) =>
      polygon.map(simplifyRing),
    );
  }
}

const geojson = JSON.parse(fs.readFileSync(source, 'utf8'));
for (const feature of geojson.features || []) simplifyGeometry(feature.geometry);
fs.writeFileSync(target, JSON.stringify(geojson));
console.log(`${path.basename(source)} -> ${path.basename(target)} (${tolerance})`);
