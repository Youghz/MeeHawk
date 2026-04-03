/**
 * Perspective transform (homography) to map video pixel coordinates
 * to court coordinates (meters).
 *
 * The user defines 4 court corners in the video frame. We compute
 * a 3x3 homography matrix that maps those pixels to the known
 * court corners in meters.
 *
 * Beach volleyball court: 16m x 8m, net at 8m (divides length).
 */

// Court corners in meters (top-left origin, y pointing down)
// Order: top-left, top-right, bottom-right, bottom-left
export const COURT_CORNERS_M = [
  [0, 0],      // top-left
  [8, 0],      // top-right  (width = 8m)
  [8, 16],     // bottom-right
  [0, 16],     // bottom-left (length = 16m)
];

export const COURT_WIDTH_M = 8;
export const COURT_LENGTH_M = 16;

/**
 * Compute 3x3 homography from 4 source points to 4 destination points.
 * Uses Direct Linear Transform (DLT).
 */
export function computeHomography(srcPts, dstPts) {
  // Build the 8x9 matrix A for Ah = 0
  const A = [];
  for (let i = 0; i < 4; i++) {
    const [xs, ys] = srcPts[i];
    const [xd, yd] = dstPts[i];
    A.push([-xs, -ys, -1, 0, 0, 0, xs * xd, ys * xd, xd]);
    A.push([0, 0, 0, -xs, -ys, -1, xs * yd, ys * yd, yd]);
  }

  // Solve via SVD (simplified: use the last row of V)
  const h = solveHomogeneous(A);
  return [
    [h[0], h[1], h[2]],
    [h[3], h[4], h[5]],
    [h[6], h[7], h[8]],
  ];
}

/**
 * Apply homography to a single point.
 * Returns [x, y] in destination coordinates.
 */
export function applyHomography(H, x, y) {
  const w = H[2][0] * x + H[2][1] * y + H[2][2];
  if (Math.abs(w) < 1e-10) return null;
  const xp = (H[0][0] * x + H[0][1] * y + H[0][2]) / w;
  const yp = (H[1][0] * x + H[1][1] * y + H[1][2]) / w;
  return [xp, yp];
}

/**
 * Solve Ah = 0 using Gaussian elimination on A^T A.
 * Returns the null-space vector (last eigenvector).
 */
function solveHomogeneous(A) {
  const n = A[0].length; // 9
  // Compute A^T * A
  const AtA = Array.from({ length: n }, () => new Array(n).fill(0));
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      let sum = 0;
      for (let k = 0; k < A.length; k++) {
        sum += A[k][i] * A[k][j];
      }
      AtA[i][j] = sum;
    }
  }

  // Power iteration to find smallest eigenvector
  // (inverse iteration on AtA)
  // For a 9x9 matrix with 4-point correspondences this is sufficient
  let v = new Array(n).fill(1);
  for (let iter = 0; iter < 100; iter++) {
    // Solve AtA * w = v using Gaussian elimination
    const w = gaussSolve(AtA.map((r) => [...r]), [...v]);
    // Normalize
    const norm = Math.sqrt(w.reduce((s, x) => s + x * x, 0));
    v = w.map((x) => x / norm);
  }
  return v;
}

function gaussSolve(M, b) {
  const n = b.length;
  const aug = M.map((row, i) => [...row, b[i]]);

  for (let col = 0; col < n; col++) {
    // Pivot
    let maxRow = col;
    for (let row = col + 1; row < n; row++) {
      if (Math.abs(aug[row][col]) > Math.abs(aug[maxRow][col])) maxRow = row;
    }
    [aug[col], aug[maxRow]] = [aug[maxRow], aug[col]];

    if (Math.abs(aug[col][col]) < 1e-12) continue;

    for (let row = col + 1; row < n; row++) {
      const factor = aug[row][col] / aug[col][col];
      for (let j = col; j <= n; j++) {
        aug[row][j] -= factor * aug[col][j];
      }
    }
  }

  // Back substitution
  const x = new Array(n).fill(0);
  for (let i = n - 1; i >= 0; i--) {
    x[i] = aug[i][n];
    for (let j = i + 1; j < n; j++) {
      x[i] -= aug[i][j] * x[j];
    }
    x[i] /= aug[i][i] || 1;
  }
  return x;
}
