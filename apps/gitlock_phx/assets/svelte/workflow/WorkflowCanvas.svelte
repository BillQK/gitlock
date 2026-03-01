<script>
  import { SvelteFlow, Background, Controls, MiniMap, Panel } from '@xyflow/svelte';
  import '@xyflow/svelte/dist/style.css';
  import AnalysisNode from './nodes/AnalysisNode.svelte';
  import NodeConfigPanel from './panels/NodeConfigPanel.svelte';
  import { flowNodes, flowEdges, flowCatalog, flowCallbacks, configPanelNode } from './stores.js';

  const nodeTypes = {
    source: AnalysisNode,
    analyze: AnalysisNode,
    output: AnalysisNode,
    logic: AnalysisNode,
  };

  let nodes = $state([]);
  let edges = $state([]);
  let catalog = $state([]);
  let callbacks = $state({
    onConnect: () => {},
    onNodeDragStop: () => {},
    onAddNode: () => {},
    onDeleteElements: () => {},
    onUpdateNodeConfig: () => {},
  });
  let panelNode = $state(null);

  flowNodes.subscribe(v => { nodes = v; });
  flowEdges.subscribe(v => { edges = v; });
  flowCatalog.subscribe(v => { catalog = v; });
  flowCallbacks.subscribe(v => { callbacks = v; });
  configPanelNode.subscribe(v => { panelNode = v; });

  function handleConnect(connection) {
    callbacks.onConnect({
      source: connection.source,
      sourceHandle: connection.sourceHandle,
      target: connection.target,
      targetHandle: connection.targetHandle,
    });
  }

  function handleNodeDragStop({ targetNode }) {
    if (targetNode) callbacks.onNodeDragStop(targetNode.id, targetNode.position);
  }

  function handleDelete({ nodes: dn, edges: de }) {
    const nids = dn.map(n => n.id);
    const eids = de.map(e => e.id);
    if (nids.length > 0 || eids.length > 0) callbacks.onDeleteElements({ nodes: nids, edges: eids });
  }

  function handleNodeClick({ node }) {
    configPanelNode.set({ ...node.data, id: node.id });
  }

  function handlePaneClick() { configPanelNode.set(null); }

  function handleDragOver(e) { e.preventDefault(); e.dataTransfer.dropEffect = 'move'; }

  function handleDrop(e) {
    e.preventDefault();
    const typeId = e.dataTransfer.getData('application/gitlock-node-type');
    if (!typeId) return;
    const b = e.currentTarget.getBoundingClientRect();
    callbacks.onAddNode(typeId, { x: e.clientX - b.left, y: e.clientY - b.top });
  }

  const categoryAccents = {
    source: '#4ecdc4',
    analyze: '#ff6b35',
    output: '#a78bfa',
    logic: '#fbbf24',
  };
</script>

<div class="flex w-full h-full">
  <!-- Sidebar palette -->
  <aside class="w-[200px] bg-[#16162a] border-r border-[#252540] px-3 py-4 overflow-y-auto shrink-0 flex flex-col gap-1">
    <div class="text-[11px] font-bold uppercase tracking-widest text-[#5e5e78] px-1 pb-2.5">Nodes</div>
    {#each catalog as category}
      <div>
        <div class="text-[10px] font-semibold uppercase tracking-wide text-[#4e4e68] px-1 pt-2.5 pb-1">{category.name}</div>
        {#each category.types as nt}
          <div
            class="flex items-center gap-2.5 px-2.5 py-2 bg-[#1e1e2e] border border-[#2a2a40] rounded-lg cursor-grab transition-all duration-100 hover:bg-[#252540] hover:border-[#3a3a58] hover:-translate-y-px active:cursor-grabbing active:translate-y-0"
            draggable="true"
            ondragstart={(e) => { e.dataTransfer.setData('application/gitlock-node-type', nt.type_id); e.dataTransfer.effectAllowed = 'move'; }}
          >
            <div class="w-[3px] h-5 rounded-sm shrink-0" style="background: {categoryAccents[nt.category] || '#888'}"></div>
            <span class="text-xs font-medium text-[#c8c8d8]">{nt.label}</span>
          </div>
        {/each}
      </div>
    {/each}
  </aside>

  <!-- Canvas -->
  <div class="flex-1 h-full min-w-0" role="application" ondragover={handleDragOver} ondrop={handleDrop}>
    <SvelteFlow
      bind:nodes
      bind:edges
      {nodeTypes}
      onconnect={handleConnect}
      onnodedragstop={handleNodeDragStop}
      ondelete={handleDelete}
      onnodeclick={handleNodeClick}
      onpaneclick={handlePaneClick}
      fitView
      colorMode="dark"
      defaultEdgeOptions={{ type: 'smoothstep', animated: true }}
    >
      <Background gap={20} />
      <Controls position="bottom-left" />
      <MiniMap />
      <Panel position="bottom-right">
        <div class="text-[11px] text-[#5e5e78] bg-[#16162a]/90 px-3 py-1 rounded-md backdrop-blur-sm">{nodes.length} nodes &middot; {edges.length} edges</div>
      </Panel>
    </SvelteFlow>
  </div>

  <!-- Config / Results panel -->
  <NodeConfigPanel />
</div>
