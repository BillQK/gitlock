<script>
  import { Handle, Position } from '@xyflow/svelte';

  let { data, selected } = $props();

  const categoryColors = {
    source: { accent: '#4ecdc4', bg: 'rgba(78, 205, 196, 0.08)' },
    analyze: { accent: '#ff6b35', bg: 'rgba(255, 107, 53, 0.08)' },
    output: { accent: '#a78bfa', bg: 'rgba(167, 139, 250, 0.08)' },
    logic: { accent: '#fbbf24', bg: 'rgba(251, 191, 36, 0.08)' },
  };

  const cat = categoryColors[data.category] || categoryColors.analyze;
  const execStatus = $derived(data.executionStatus);
  const statusText = $derived(data.statusText);

  const configSummary = $derived.by(() => {
    if (!data.config_schema || data.config_schema.length === 0) return null;
    const required = data.config_schema.filter(f => f.required);
    const missing = required.filter(f => {
      const v = data.config?.[f.key];
      return v === undefined || v === null || v === '';
    });
    if (missing.length > 0) return { status: 'missing', text: 'Needs configuration' };
    const url = data.config?.repo_url;
    if (url) {
      const short = url.replace(/^https?:\/\//, '').replace(/\.git$/, '');
      return { status: 'ok', text: short.length > 30 ? '...' + short.slice(-30) : short };
    }
    return { status: 'ok', text: 'Configured' };
  });

  // Dynamic border/shadow classes based on execution state
  const nodeClasses = $derived.by(() => {
    const base = 'rounded-[10px] min-w-[200px] font-sans shadow-md transition-all duration-150 overflow-hidden';
    const bg = 'bg-[#1e1e2e] border border-[#2e2e42]';
    const hover = 'hover:border-[#3e3e56] hover:shadow-lg';

    if (execStatus === 'running') return `${base} ${bg} border-amber-500 shadow-[0_0_0_1px_#f59e0b,0_0_20px_rgba(245,158,11,0.15)]`;
    if (execStatus === 'done') return `${base} ${bg} border-emerald-500 shadow-[0_0_0_1px_#10b981,0_0_20px_rgba(16,185,129,0.15)]`;
    if (execStatus === 'error') return `${base} ${bg} border-red-500 shadow-[0_0_0_1px_#ef4444,0_0_20px_rgba(239,68,68,0.15)]`;
    if (selected) return `${base} bg-[#1e1e2e] border shadow-lg`;
    return `${base} ${bg} ${hover}`;
  });
</script>

<div
  class={nodeClasses}
  style={selected && !execStatus ? `border-color: ${cat.accent}; box-shadow: 0 0 0 1px ${cat.accent}, 0 4px 16px rgba(0,0,0,0.35)` : ''}
>
  <!-- Header -->
  <div class="flex items-center gap-2.5 px-3.5 py-2.5" style="background: {cat.bg}">
    <div class="w-1 h-7 rounded-sm shrink-0" style="background: {cat.accent}"></div>
    <div class="flex flex-col flex-1 min-w-0">
      <span class="text-[13px] font-semibold text-[#e8e8ee] truncate leading-tight">{data.label}</span>
      <span class="text-[10px] uppercase tracking-wide text-[#6e6e88] leading-tight">{data.category}</span>
    </div>
    {#if execStatus}
      <div class="w-5 h-5 shrink-0 {execStatus === 'running' ? 'text-amber-500' : execStatus === 'done' ? 'text-emerald-500' : 'text-red-500'}">
        {#if execStatus === 'running'}
          <svg class="w-4 h-4 animate-spin" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="2" stroke-dasharray="28" stroke-dashoffset="8"/></svg>
        {:else if execStatus === 'done'}
          <svg class="w-4 h-4" viewBox="0 0 16 16" fill="none"><path d="M3 8.5L6.5 12L13 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
        {:else}
          <svg class="w-4 h-4" viewBox="0 0 16 16" fill="none"><path d="M4 4L12 12M12 4L4 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Status text (running) -->
  {#if execStatus === 'running' && statusText}
    <div class="flex items-center gap-1.5 px-3.5 py-1.5 text-[10px] text-amber-500 border-t border-[#252540]">
      <svg class="w-2.5 h-2.5 animate-spin shrink-0" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="2" stroke-dasharray="28" stroke-dashoffset="8"/></svg>
      <span class="truncate">{statusText}</span>
    </div>
  {:else if configSummary}
    <div class="flex items-center gap-1.5 px-3.5 py-1.5 text-[10px] border-t border-[#252540] {configSummary.status === 'missing' ? 'text-amber-500' : 'text-emerald-400'}">
      {#if configSummary.status === 'missing'}
        <svg class="w-3 h-3 shrink-0" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/><path d="M8 4.5V9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><circle cx="8" cy="11.5" r="0.75" fill="currentColor"/></svg>
      {:else}
        <svg class="w-3 h-3 shrink-0" viewBox="0 0 16 16" fill="none"><path d="M3 8.5L6.5 12L13 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
      {/if}
      <span class="truncate">{configSummary.text}</span>
    </div>
  {/if}

  <!-- Ports -->
  {#if data.input_ports?.length > 0 || data.output_ports?.length > 0}
    <div class="py-1.5 pb-2">
      {#if data.input_ports?.length > 0}
        {#each data.input_ports as port}
          <div class="flex items-center gap-1.5 px-3.5 py-0.5 text-[11px] relative">
            <Handle
              type="target"
              position={Position.Left}
              id={port.id}
              style="background: {cat.accent}; border: 2px solid #1e1e2e; width: 12px; height: 12px; border-radius: 50%;"
            />
            <span class="text-[#b0b0c0]">{port.name}</span>
            <span class="text-[#5e5e78] text-[10px] opacity-60">{port.data_type}</span>
          </div>
        {/each}
      {/if}
      {#if data.output_ports?.length > 0}
        {#each data.output_ports as port}
          <div class="flex items-center justify-end gap-1.5 px-3.5 py-0.5 text-[11px] relative">
            <span class="text-[#5e5e78] text-[10px] opacity-60">{port.data_type}</span>
            <span class="text-[#b0b0c0]">{port.name}</span>
            <Handle
              type="source"
              position={Position.Right}
              id={port.id}
              style="background: {cat.accent}; border: 2px solid #1e1e2e; width: 12px; height: 12px; border-radius: 50%;"
            />
          </div>
        {/each}
      {/if}
    </div>
  {/if}
</div>
