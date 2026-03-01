/**
 * Shared state between the LiveView hook and Svelte components.
 */
import { writable } from 'svelte/store';

/** @type {import('svelte/store').Writable<Array>} SvelteFlow-format nodes */
export const flowNodes = writable([]);

/** @type {import('svelte/store').Writable<Array>} SvelteFlow-format edges */
export const flowEdges = writable([]);

/** @type {import('svelte/store').Writable<Array>} Node catalog grouped by category */
export const flowCatalog = writable([]);

/** @type {import('svelte/store').Writable<Object|null>} Node selected for results display */
export const selectedResultNode = writable(null);

/** @type {import('svelte/store').Writable<Object|null>} Node selected for config editing */
export const configPanelNode = writable(null);

/** @type {import('svelte/store').Writable<Object>} Callbacks from Svelte → Hook */
export const flowCallbacks = writable({
  onConnect: (_connection) => {},
  onNodeDragStop: (_nodeId, _position) => {},
  onAddNode: (_typeId, _position) => {},
  onDeleteElements: (_payload) => {},
  onUpdateNodeConfig: (_nodeId, _config) => {},
});
