import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Link from "@tiptap/extension-link"
import { Markdown } from "tiptap-markdown"

const TiptapEditor = {
  mounted() {
    const hiddenInput = document.getElementById(this.el.dataset.inputId)
    const hook = this

    this.editor = new Editor({
      element: this.el,
      extensions: [
        StarterKit,
        Link.configure({ openOnClick: false }),
        Markdown.configure({ html: false, transformPastedText: true, transformInputRules: true }),
      ],
      content: hiddenInput?.value || "",
      onUpdate: ({ editor }) => {
        if (hiddenInput) {
          hiddenInput.value = editor.storage.markdown.getMarkdown()
        }
      },
      editorProps: {
        handlePaste: (view, event) => {
          const text = event.clipboardData?.getData('text/plain')?.trim()
          if (!text || !text.match(/^sblk_[a-z0-9_]+$/)) return false

          hook.pushEventTo(hook.el, 'get_subblock_text', { id: text }, ({ text: subText, id }) => {
            if (!subText) return
            const { state } = view
            const linkMark = state.schema.marks.link
            if (!linkMark) return
            const from = state.selection.from
            const to = state.selection.to
            const mark = linkMark.create({ href: `sblk://${id}` })
            const node = state.schema.text(subText, [mark])
            view.dispatch(state.tr.replaceSelectionWith(node, false))
          })
          event.preventDefault()
          return true
        }
      },
    })
  },

  destroyed() {
    this.editor?.destroy()
  },
}

export default TiptapEditor
