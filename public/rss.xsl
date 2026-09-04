<?xml version="1.0" encoding="UTF-8"?>
<!--
  Browsers show a raw feed as an XML tree, which looks broken to anyone who clicked
  the RSS button expecting a page. This stylesheet is ignored by feed readers and
  only ever runs in a browser, so the feed itself is unchanged.
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>

  <xsl:template match="/rss/channel">
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><xsl:value-of select="title"/></title>
        <style>
          :root { color-scheme: dark; }
          body {
            margin: 0; padding: 4rem 1.5rem;
            background: #0c0e13; color: #e3e7ee;
            font: 16px/1.6 ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif;
          }
          main { max-width: 44rem; margin: 0 auto; }
          a { color: #cfc4fb; }
          h1 { font-size: 1.75rem; margin: 0 0 .5rem; }
          .lede { color: #8e97a6; margin: 0 0 2rem; }
          .note {
            border: 1px solid #272b35; border-radius: .6rem;
            background: #14161d; padding: 1rem 1.25rem; margin-bottom: 2.5rem;
          }
          .note p { margin: 0 0 .5rem; }
          .note p:last-child { margin: 0; }
          code {
            font-family: ui-monospace, 'Cascadia Code', Consolas, monospace;
            font-size: .875em; background: #1f232b; padding: .15em .4em; border-radius: .3em;
            overflow-wrap: anywhere;
          }
          article { border-top: 1px solid #1f232b; padding: 1.5rem 0; }
          article h2 { font-size: 1.1rem; margin: 0 0 .35rem; }
          article h2 a { text-decoration: none; }
          article h2 a:hover { text-decoration: underline; }
          time { color: #626b7a; font-size: .875rem; }
          article p { margin: .5rem 0 0; color: #bfc6d2; }
        </style>
      </head>
      <body>
        <main>
          <h1><xsl:value-of select="title"/></h1>
          <p class="lede"><xsl:value-of select="description"/></p>

          <div class="note">
            <p>This is an RSS feed. Paste the address below into a feed reader to
               get new posts as they are written.</p>
            <p><code><xsl:value-of select="atom:link[@rel='self']/@href"/></code></p>
            <p><a href="{link}">Back to the site</a></p>
          </div>

          <xsl:for-each select="item">
            <article>
              <h2><a href="{link}"><xsl:value-of select="title"/></a></h2>
              <time><xsl:value-of select="substring(pubDate, 1, 16)"/></time>
              <p><xsl:value-of select="description"/></p>
            </article>
          </xsl:for-each>
        </main>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
