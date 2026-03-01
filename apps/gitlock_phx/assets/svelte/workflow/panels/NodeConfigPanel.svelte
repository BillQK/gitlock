<script>
  import { configPanelNode, flowCallbacks, flowNodes } from '../stores.js';

  let node = $state(null);
  let config = $state({});
  let callbacks = $state({ onUpdateNodeConfig: () => {} });
  let schema = $state([]);

  configPanelNode.subscribe(v => {
    node = v;
    if (v) {
      config = { ...(v.config || {}) };
      schema = v.config_schema || [];
    }
  });
  flowCallbacks.subscribe(v => { callbacks = v; });

  function updateField(key, value, type) {
    if (type === 'integer') {
      config[key] = value === '' ? null : parseInt(value, 10);
    } else if (type === 'date') {
      config[key] = value === '' ? null : value;
    } else {
      config[key] = value;
    }
    if (node) {
      callbacks.onUpdateNodeConfig(node.id, { ...config });
      flowNodes.update(nodes =>
        nodes.map(n =>
          n.id === node.id
            ? { ...n, data: { ...n.data, config: { ...config } } }
            : n
        )
      );
    }
  }

  function close() { configPanelNode.set(null); }

  let hasRequiredFields = $derived(
    schema.filter(f => f.required).every(f => {
      const val = config[f.key];
      return val !== undefined && val !== null && val !== '';
    })
  );

  let parsedResult = $derived.by(() => {
    if (!node?.result) return null;
    try {
      return typeof node.result === 'string' ? JSON.parse(node.result) : node.result;
    } catch { return node.result; }
  });

  function formatValue(v) {
    if (v === null || v === undefined) return '\u2014';
    if (typeof v === 'number') return Number.isInteger(v) ? v.toString() : v.toFixed(3);
    return String(v);
  }

  const catColors = { source: '#4ecdc4', analyze: '#ff6b35', output: '#a78bfa', logic: '#fbbf24' };
</script>

{#if node}
  <aside class="w-80 bg-[#16162a] border-l border-[#252540] flex flex-col shrink-0 overflow-hidden">
    <!-- Header -->
    <div class="flex items-center justify-between px-4 py-3.5 border-b border-[#252540] shrink-0">
      <div class="flex items-center gap-2.5 min-w-0">
        <div class="w-1 h-7 rounded-sm shrink-0" style="background: {catColors[node.category] || '#888'}"></div>
        <div>
          <h3 class="text-sm font-semibold text-[#e0e0ee] m-0 leading-tight">{node.label}</h3>
          <span class="text-[10px] uppercase tracking-wide text-[#5e5e78]">{node.category}</span>
        </div>
      </div>
      <button
        class="p-1.5 rounded-md text-[#5e5e78] hover:text-[#e0e0ee] hover:bg-[#252540] cursor-pointer bg-transparent border-none flex items-center shrink-0"
        onclick={close}
      >
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M1 1L13 13M13 1L1 13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>
      </button>
    </div>

    <div class="flex-1 overflow-y-auto">
      <!-- Config fields -->
      {#if schema.length > 0}
        <div class="px-4 py-3.5 border-b border-[#1e1e30]">
          <div class="text-[10px] font-semibold uppercase tracking-wide text-[#4e4e68] mb-2.5">Configuration</div>
          {#each schema as field}
            <div class="flex flex-col gap-1 mb-2.5">
              <label for="cfg-{field.key}" class="text-xs font-medium text-[#8e8ea8]">
                {field.label}
                {#if field.required}<span class="text-red-400">*</span>{/if}
              </label>
              {#if field.type === 'select'}
                <select
                  id="cfg-{field.key}"
                  value={config[field.key] ?? field.default ?? ''}
                  onchange={(e) => updateField(field.key, e.target.value, field.type)}
                  class="bg-[#1e1e2e] border border-[#2e2e48] text-[#e0e0ee] px-3 py-2 rounded-md text-[13px] font-sans outline-none transition-colors duration-100 w-full focus:border-indigo-500 placeholder:text-[#4e4e68]"
                >
                  {#each field.options || [] as opt}
                    <option value={opt.value}>{opt.label}</option>
                  {/each}
                </select>
              {:else if field.type === 'integer'}
                <input
                  id="cfg-{field.key}"
                  type="number"
                  value={config[field.key] ?? field.default ?? ''}
                  placeholder={field.placeholder || ''}
                  oninput={(e) => updateField(field.key, e.target.value, field.type)}
                  class="bg-[#1e1e2e] border border-[#2e2e48] text-[#e0e0ee] px-3 py-2 rounded-md text-[13px] font-sans outline-none transition-colors duration-100 w-full focus:border-indigo-500 placeholder:text-[#4e4e68]"
                />
              {:else if field.type === 'date'}
                <input
                  id="cfg-{field.key}"
                  type="date"
                  value={config[field.key] ?? field.default ?? ''}
                  oninput={(e) => updateField(field.key, e.target.value, field.type)}
                  class="bg-[#1e1e2e] border border-[#2e2e48] text-[#e0e0ee] px-3 py-2 rounded-md text-[13px] font-sans outline-none transition-colors duration-100 w-full focus:border-indigo-500 placeholder:text-[#4e4e68]"
                />
              {:else}
                <input
                  id="cfg-{field.key}"
                  type="text"
                  value={config[field.key] ?? field.default ?? ''}
                  placeholder={field.placeholder || ''}
                  oninput={(e) => updateField(field.key, e.target.value, field.type)}
                  class="bg-[#1e1e2e] border border-[#2e2e48] text-[#e0e0ee] px-3 py-2 rounded-md text-[13px] font-sans outline-none transition-colors duration-100 w-full focus:border-indigo-500 placeholder:text-[#4e4e68]"
                />
              {/if}
            </div>
          {/each}

          {#if !hasRequiredFields}
            <div class="flex items-center gap-2 text-[11px] text-amber-500 px-3 py-2 bg-amber-500/[0.08] border border-amber-500/[0.12] rounded-md">
              <svg class="shrink-0" width="14" height="14" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/><path d="M8 4.5V9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><circle cx="8" cy="11.5" r="0.75" fill="currentColor"/></svg>
              Required fields missing
            </div>
          {/if}
        </div>
      {/if}

      <!-- Execution results -->
      {#if node.executionStatus === 'error'}
        <div class="px-4 py-3.5 border-b border-[#1e1e30]">
          <div class="text-[10px] font-semibold uppercase tracking-wide text-red-400 mb-2.5">Error</div>
          <div class="bg-red-500/[0.08] border border-red-500/[0.12] rounded-md p-2.5">
            <pre class="text-red-400 text-[11px] m-0 whitespace-pre-wrap break-words font-mono">{node.error || 'Unknown error'}</pre>
          </div>
        </div>
      {:else if node.executionStatus === 'done' && parsedResult}
        <div class="px-4 py-3.5 border-b border-[#1e1e30]">
          <div class="text-[10px] font-semibold uppercase tracking-wide text-emerald-400 mb-2.5">Output</div>
          {#if Array.isArray(parsedResult)}
            <div class="text-[11px] text-[#5e5e78] mb-2">{parsedResult.length} result{parsedResult.length !== 1 ? 's' : ''}</div>
            {#if parsedResult.length > 0}
              <div class="overflow-x-auto">
                <table class="w-full border-collapse text-[11px]">
                  <thead>
                    <tr>
                      {#each Object.keys(parsedResult[0]) as col}
                        <th class="text-left text-[#6e6e88] font-semibold px-2 py-1.5 border-b border-[#252540] whitespace-nowrap capitalize sticky top-0 bg-[#16162a]">{col.replace(/_/g, ' ')}</th>
                      {/each}
                    </tr>
                  </thead>
                  <tbody>
                    {#each parsedResult.slice(0, 50) as row}
                      <tr class="hover:bg-[#1e1e2e]">
                        {#each Object.values(row) as v}
                          <td class="text-[#b0b0c0] px-2 py-1 border-b border-[#1e1e30] max-w-[160px] truncate" title={String(v)}>{formatValue(v)}</td>
                        {/each}
                      </tr>
                    {/each}
                  </tbody>
                </table>
                {#if parsedResult.length > 50}
                  <div class="text-[#5e5e78] text-[11px] text-center py-1.5">Showing 50 of {parsedResult.length}</div>
                {/if}
              </div>
            {/if}
          {:else if typeof parsedResult === 'object'}
            <div class="overflow-x-auto">
              <table class="w-full border-collapse text-[11px]">
                <tbody>
                  {#each Object.entries(parsedResult) as [k, v]}
                    <tr class="hover:bg-[#1e1e2e]">
                      <th class="text-left w-[110px] text-purple-400 font-semibold px-2 py-1.5 border-b border-[#1e1e30] capitalize">{k.replace(/_/g, ' ')}</th>
                      <td class="text-[#b0b0c0] px-2 py-1 border-b border-[#1e1e30]">{formatValue(v)}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {:else}
            <pre class="text-[#b0b0c0] text-[11px] m-0 whitespace-pre-wrap break-words font-mono bg-[#1e1e2e] p-2.5 rounded-md">{String(parsedResult)}</pre>
          {/if}
        </div>
      {:else if node.executionStatus === 'running'}
        <div class="px-4 py-3.5 border-b border-[#1e1e30]">
          <div class="flex items-center gap-2 text-amber-500 text-xs py-2">
            <svg class="w-4 h-4 animate-spin" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="2" stroke-dasharray="28" stroke-dashoffset="8"/></svg>
            Running...
          </div>
        </div>
      {/if}

      <!-- Empty state -->
      {#if schema.length === 0 && !node.executionStatus}
        <div class="text-[#4e4e68] text-xs text-center px-4 py-8">Click Execute to run this node</div>
      {/if}
    </div>
  </aside>
{/if}
