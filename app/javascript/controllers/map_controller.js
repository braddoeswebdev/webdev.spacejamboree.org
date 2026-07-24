import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

export default class extends Controller {
  static targets = ["stream"]
  static values = { mapId: Number }

  connect() {
    this.cy = cytoscape({
      container: this.element.querySelector("#cy"),
      style: [
        {
          selector: "node",
          style: {
            "background-color": "data(org_color)",
            label: "data(label)",
            color: "#333",
            "font-size": "12px",
            "text-valign": "bottom",
            "text-halign": "center",
            "text-wrap": "wrap",
            width: 30,
            height: 30,
            "border-width": 1,
            "border-color": "#555"
          }
        },
        {
          selector: "node[is_private = true]",
          style: {
            "border-color": "#999",
            "border-style": "dashed"
          }
        },
        {
          selector: "edge",
          style: {
            width: 2,
            "line-color": "#888",
            "target-arrow-color": "#888",
            "target-arrow-shape": "triangle",
            "curve-style": "bezier",
            label: "data(hop_number)",
            "font-size": "10px",
            color: "#666"
          }
        },
        {
          selector: "edge[spans_gap = true]",
          style: {
            "line-style": "dashed",
            opacity: 0.5
          }
        },
        {
          selector: "edge[timed_out = true]",
          style: {
            opacity: 0.2
          }
        }
      ],
      layout: { name: "preset" }
    })

    this.loadInitialData()

    this.cy.on("dragfree", "node", (evt) => {
      this.savePosition(evt.target)
    })

    this.cy.on("mouseover", "node", (evt) => {
      const node = evt.target
      const tip = document.getElementById("node-tooltip")
      if (!tip) return
      let html = `<strong>${node.data("label")}</strong><br>IP: ${node.data("ip")}`
      if (node.data("org_name")) {
        html += `<br>Org: ${node.data("org_name")}`
      }
      html += `<br>Scout: ${node.data("user_name")}`
      tip.innerHTML = html
      tip.style.display = "block"
    })

    this.cy.on("mouseout", "node", () => {
      const tip = document.getElementById("node-tooltip")
      if (tip) tip.style.display = "none"
    })

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.tagName === "SCRIPT" && node.type === "application/json") {
            this.addElements(node.textContent)
            this.runLayoutForUnpositioned()
          }
        }
      }
    })

    this.observer.observe(this.streamTarget, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
    this.cy.destroy()
  }

  loadInitialData() {
    const scripts = this.streamTarget.querySelectorAll("script[type='application/json']")
    scripts.forEach((script) => this.addElements(script.textContent))
    this.runLayoutForUnpositioned()
  }

  addElements(json) {
    const data = JSON.parse(json)
    if (data.nodes?.length) {
      const existingIds = new Set(this.cy.nodes().map((n) => n.id()))
      const newNodes = data.nodes.filter((n) => !existingIds.has(n.data.id))
      if (newNodes.length) {
        this.cy.add(
          newNodes.map((n) => ({
            group: "nodes",
            data: {
              ...n.data,
              is_private: n.data.is_private || false
            },
            position:
              n.data.x != null && n.data.y != null
                ? { x: n.data.x, y: n.data.y }
                : undefined
          }))
        )
      }
    }
    if (data.edges?.length) {
      const existingEdgeIds = new Set(this.cy.edges().map((e) => e.id()))
      const newEdges = data.edges.filter((e) => !existingEdgeIds.has(e.data.id))
      if (newEdges.length) {
        this.cy.add(
          newEdges.map((e) => ({
            group: "edges",
            data: e.data
          }))
        )
      }
    }
  }

  runLayoutForUnpositioned() {
    const unpositioned = this.cy
      .nodes()
      .filter((n) => n.position().x === 0 && n.position().y === 0)
    if (unpositioned.length === 0) return

    const grouped = unpositioned.filter((n) => n.data("domain"))
    const regular = unpositioned.filter((n) => !n.data("domain"))

    if (grouped.length) {
      const byDomain = {}
      grouped.forEach((n) => {
        const d = n.data("domain")
        if (!byDomain[d]) byDomain[d] = []
        byDomain[d].push(n)
      })
      let offset = 0
      for (const nodes of Object.values(byDomain)) {
        nodes.forEach((n, i) => {
          const col = i % 3
          const row = Math.floor(i / 3)
          n.position({ x: offset + col * 50, y: row * 50 })
        })
        offset += 200
      }
      grouped.forEach((n) => this.savePosition(n))
    }

    if (regular.length) {
      const layout = regular.layout({
        name: "breadthfirst",
        fit: true,
        directed: true,
        spacingFactor: 1.5
      })
      layout.run()
      layout.on("layoutstop", () => {
        regular.forEach((n) => this.savePosition(n))
      })
    }
  }

  savePosition(node) {
    const id = node.data("id")
    if (!id || !id.startsWith("node_")) return

    const nodeId = id.replace("node_", "")
    const x = Math.round(node.position("x") * 100) / 100
    const y = Math.round(node.position("y") * 100) / 100

    fetch(`/network_nodes/${nodeId}/position`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ x, y })
    })
  }
}
