import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import { Markdown } from "tiptap-markdown"

const TiptapEditor = {
  mounted() {
    const hiddenInput = document.getElementById(this.el.dataset.inputId)

    this.editor = new Editor({
      element: this.el,
      extensions: [
        StarterKit,
        Markdown.configure({ html: false, transformPastedText: true, transformInputRules: true }),
      ],
      content: hiddenInput?.value || "",
      onUpdate: ({ editor }) => {
        if (hiddenInput) {
          hiddenInput.value = editor.storage.markdown.getMarkdown()
        }
      },
    })
  },

  destroyed() {
    this.editor?.destroy()
  },
}

export default TiptapEditor
