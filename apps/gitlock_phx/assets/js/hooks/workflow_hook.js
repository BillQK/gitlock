import { mount, unmount } from "svelte";
import WorkflowCanvas from "../../svelte/workflow/WorkflowCanvas.svelte";
import {
  flowNodes,
  flowEdges,
  flowCatalog,
  flowCallbacks,
} from "../../svelte/workflow/stores.js";

/**
 * Transforms Elixir Pipeline JSON into SvelteFlow format.
 */
function pipelineToFlow(pipeline) {
  const nodes = Object.values(pipeline.nodes || {}).map((node) => ({
    id: node.id,
    type: node.category || "analyze",
    position: { x: node.position[0] || 0, y: node.position[1] || 0 },
    data: {
      label: node.label,
      category: node.category,
      type: node.type,
      input_ports: node.input_ports || [],
      output_ports: node.output_ports || [],
      config: node.config || {},
      config_schema: node.config_schema || [],
    },
  }));

  const edges = Object.values(pipeline.edges || {}).map((edge) => ({
    id: edge.id,
    source: edge.source_node_id,
    target: edge.target_node_id,
    sourceHandle: edge.source_port_id,
    targetHandle: edge.target_port_id,
    type: "smoothstep",
    animated: true,
  }));

  return { nodes, edges };
}

const WorkflowHook = {
  mounted() {
    // Register callbacks: Svelte → LiveView
    flowCallbacks.set({
      onConnect: (connection) => {
        this.pushEvent("connect", {
          source_node_id: connection.source,
          source_port_id: connection.sourceHandle,
          target_node_id: connection.target,
          target_port_id: connection.targetHandle,
        });
      },

      onNodeDragStop: (nodeId, position) => {
        this.pushEvent("node_moved", {
          node_id: nodeId,
          position: { x: position.x, y: position.y },
        });
      },

      onAddNode: (typeId, position) => {
        this.pushEvent("add_node", {
          type_id: typeId,
          position: { x: position.x, y: position.y },
        });
      },

      onDeleteElements: (payload) => {
        this.pushEvent("delete_elements", payload);
      },

      onUpdateNodeConfig: (nodeId, config) => {
        this.pushEvent("update_node_config", {
          node_id: nodeId,
          config: config,
        });
      },
    });

    // Listen for state pushes from LiveView
    this.handleEvent("pipeline_state", (payload) => {
      const { nodes, edges } = pipelineToFlow(payload.pipeline);
      flowNodes.set(nodes);
      flowEdges.set(edges);
    });

    this.handleEvent("catalog", (payload) => {
      flowCatalog.set(payload.catalog);
    });

    // Mount Svelte component
    this.component = mount(WorkflowCanvas, {
      target: this.el,
    });

    // Listen for node execution progress
    this.handleEvent("node_progress", ({ node_id, status, result, error, status_text }) => {
      flowNodes.update((nodes) =>
        nodes.map((n) =>
          n.id === node_id
            ? {
                ...n,
                data: {
                  ...n.data,
                  executionStatus: status,
                  statusText: status_text || n.data.statusText || null,
                  result: result || n.data.result || null,
                  error: error || null,
                },
              }
            : n
        )
      );
    });

    this.handleEvent("execution_started", () => {
      flowNodes.update((nodes) =>
        nodes.map((n) => ({
          ...n,
          data: { ...n.data, executionStatus: null, statusText: null, result: null, error: null },
        }))
      );
    });

    // Request initial state
    this.pushEvent("request_state", {});
  },

  destroyed() {
    if (this.component) {
      unmount(this.component);
    }
  },
};

export default WorkflowHook;
