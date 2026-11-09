// Offsets are absolute character positions across all text nodes (marks included),
// so they remain stable regardless of which marks exist at capture or render time.
function getTextOffset(container, node, offset) {
  let total = 0
  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT)
  while (walker.nextNode()) {
    if (walker.currentNode === node) return total + offset
    total += walker.currentNode.textContent.length
  }
  return offset
}

function findNodeAtOffset(container, targetOffset) {
  let total = 0
  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT)
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
    if (sub.is_stale) {
      mark.classList.add('highlight-stale')
      mark.title = 'This highlight is from an older version of the block'
    } else if (sub.is_annotation) {
      mark.classList.add('highlight-annotation')
      mark.title = 'Argument annotation — click to copy ID'
    } else {
      mark.classList.add('highlight-active')
      mark.title = 'Click to copy highlight ID'
    }

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
