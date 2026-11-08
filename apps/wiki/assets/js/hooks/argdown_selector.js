function getTextOffset(container, node, offset) {
  let total = 0
  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, {
    acceptNode(n) {
      if (n.parentElement.closest('mark[data-subblock-id]')) return NodeFilter.FILTER_REJECT
      return NodeFilter.FILTER_ACCEPT
    }
  })
  while (walker.nextNode()) {
    if (walker.currentNode === node) return total + offset
    total += walker.currentNode.textContent.length
  }
  // Node was inside an existing mark — walk unfiltered to get its raw position
  const raw = document.createTreeWalker(container, NodeFilter.SHOW_TEXT)
  let rawTotal = 0
  while (raw.nextNode()) {
    if (raw.currentNode === node) return rawTotal + offset
    if (!raw.currentNode.parentElement.closest('mark[data-subblock-id]')) {
      rawTotal += raw.currentNode.textContent.length
    }
  }
  return offset
}

// Find the text node and local offset for a given cumulative character position,
// skipping text nodes inside <mark data-subblock-id> elements (already injected)
function findNodeAtOffset(container, targetOffset) {
  let total = 0
  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      // Skip text inside already-injected marks to avoid double-counting
      if (node.parentElement.closest('mark[data-subblock-id]')) return NodeFilter.FILTER_REJECT
      return NodeFilter.FILTER_ACCEPT
    }
  })
  while (walker.nextNode()) {
    const len = walker.currentNode.textContent.length
    if (total + len >= targetOffset) {
      return { node: walker.currentNode, offset: targetOffset - total }
    }
    total += len
  }
  return null
}

function clearHighlights(container) {
  container.querySelectorAll('mark[data-subblock-id]').forEach(mark => {
    const parent = mark.parentNode
    while (mark.firstChild) parent.insertBefore(mark.firstChild, mark)
    parent.removeChild(mark)
    parent.normalize()
  })
}

function renderHighlights(container, subblocks) {
  clearHighlights(container)
  if (!subblocks || subblocks.length === 0) return

  // Sort ascending so earlier highlights don't shift later offsets
  const sorted = [...subblocks].sort((a, b) => a.from_ix - b.from_ix)

  sorted.forEach(sub => {
    const start = findNodeAtOffset(container, sub.from_ix)
    const end = findNodeAtOffset(container, sub.to_ix)
    if (!start || !end) return

    const range = document.createRange()
    range.setStart(start.node, start.offset)
    range.setEnd(end.node, end.offset)

    const mark = document.createElement('mark')
    mark.dataset.subblockId = sub.id
    mark.dataset.subblockText = sub.text || ''
    mark.classList.add(sub.is_stale ? 'highlight-stale' : 'highlight-active')
    mark.title = sub.is_stale ? 'This highlight is from an older version of the block' : 'Click to copy highlight ID'

    try {
      range.surroundContents(mark)
      mark.addEventListener('click', e => {
        e.stopPropagation()
        navigator.clipboard.writeText(sub.id).then(() => {
          const original = mark.title
          mark.title = 'Copied!'
          setTimeout(() => { mark.title = original }, 1500)
        })
      })
    } catch (_) {
      // Range spans element boundaries — skip gracefully
    }
  })
}

const ArgdownSelector = {
  mounted() {
    this.renderHighlights()

    this.handleMouseUp = () => {
      const selection = window.getSelection()
      if (!selection || selection.isCollapsed || selection.rangeCount === 0) return

      const selectedText = selection.toString().trim()
      if (!selectedText) return

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

  updated() {
    this.renderHighlights()
  },

  destroyed() {
    this.el.removeEventListener("mouseup", this.handleMouseUp)
  },

  renderHighlights() {
    try {
      const subblocks = JSON.parse(this.el.dataset.subblocks || '[]')
      renderHighlights(this.el, subblocks)
    } catch (_) {}
  }
}

export default ArgdownSelector
