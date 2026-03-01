/**
 * Shared utilities for Svelte components.
 * Formatting helpers, constants, etc.
 */

/**
 * Format a risk score (0-1) into a human-readable label.
 */
export function riskLevel(score) {
  if (score > 0.8) return 'critical';
  if (score > 0.6) return 'high';
  if (score > 0.3) return 'medium';
  return 'low';
}

/**
 * Map risk level to daisyUI color class.
 */
export function riskColor(level) {
  const colors = {
    critical: 'text-error',
    high: 'text-warning',
    medium: 'text-info',
    low: 'text-success',
  };
  return colors[level] || 'text-base-content/50';
}

/**
 * Truncate a file path for display, keeping the tail.
 */
export function truncatePath(path, maxLen = 40) {
  if (!path || path.length <= maxLen) return path;
  return '…' + path.slice(-(maxLen - 1));
}
