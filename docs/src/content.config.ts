import { defineCollection } from 'astro:content';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { blogSchema } from 'starlight-blog/schema';
import { starlightTagsExtension } from 'starlight-tags/schema';

export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    // Both plugins extend the same collection. They each declare `tags` as an
    // optional string array, so merging is safe — starlight-tags wins the overlap.
    schema: docsSchema({
      extend: (context) => blogSchema(context).merge(starlightTagsExtension),
    }),
  }),
};
