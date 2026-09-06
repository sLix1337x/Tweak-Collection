/**
 * Wraps every markdown table in a scrolling container.
 *
 * A table wide enough to overflow has to scroll somewhere, and the usual
 * shortcut is `display: block; overflow: auto` on the table itself. That works
 * for the scrolling and breaks the layout: as a block the table stops filling
 * its column, so a narrow table sits in the corner of a full-width border with
 * dead space beside it, and the header background stops halfway across the row.
 *
 * With a wrapper the table stays `display: table; width: 100%` and the overflow
 * belongs to the element around it.
 *
 * This is a Sätteri hast plugin rather than a rehype one: `markdown.rehypePlugins`
 * needs `@astrojs/markdown-remark` reinstalled now that Sätteri is Astro's default
 * processor, and `hastPlugins` does the same job with what is already here.
 */
export const tableWrapper = {
  name: 'tc-table-wrapper',
  element: {
    filter: ['table'],
    visit(node, ctx) {
      ctx.wrapNode(node, {
        type: 'element',
        tagName: 'div',
        properties: { className: ['tc-table'] },
        children: [],
      });
    },
  },
};
