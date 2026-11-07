function getTextOffset(container, node, offset) {
  let total = 0
  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT)
  while (walker.nextNode()) {
    if (walker.currentNode === node) return total + offset
    total += walker.currentNode.textContent.length
  }
  return offset
}

const ArgdownSelector = {
  mounted() {
    console.log("[ArgdownSelector] mounted for block", this.el.dataset.blockId)

    this.handleMouseUp = () => {
      const selection = window.getSelection()
      if (!selection || selection.isCollapsed || selection.rangeCount === 0) return

      const selectedText = selection.toString().trim()
      if (!selectedText) return

      console.log("[ArgdownSelector] selection detected:", selectedText)

      const range = selection.getRangeAt(0)
      const fromIx = getTextOffset(this.el, range.startContainer, range.startOffset)
      const toIx = getTextOffset(this.el, range.endContainer, range.endOffset)

      this.pushEvent("text_selected", {
        block_id: this.el.dataset.blockId,
        text: selectedText,
        from_ix: fromIx,
        to_ix: toIx
      })
    }

    this.el.addEventListener("mouseup", this.handleMouseUp)
  },

  destroyed() {
    this.el.removeEventListener("mouseup", this.handleMouseUp)
  }
}

export default ArgdownSelector
