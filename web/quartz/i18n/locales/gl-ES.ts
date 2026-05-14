import { Translation } from "./definition"

export default {
  propertyDefaults: {
    title: "Sen título",
    description: "Sen descrición",
  },
  components: {
    callout: {
      note: "Nota",
      abstract: "Resumo",
      info: "Información",
      todo: "Por facer",
      tip: "Consello",
      success: "Éxito",
      question: "Pregunta",
      warning: "Advertencia",
      failure: "Fallo",
      danger: "Perigo",
      bug: "Erro",
      example: "Exemplo",
      quote: "Cita",
    },
    backlinks: {
      title: "Retroligazóns",
      noBacklinksFound: "Non se atoparon retroligazóns",
    },
    themeToggle: {
      lightMode: "Modo claro",
      darkMode: "Modo escuro",
    },
    readerMode: {
      title: "Modo lector",
    },
    explorer: {
      title: "Explorador",
    },
    footer: {
      createdWith: "Creado con",
    },
    graph: {
      title: "Vista Gráfica",
    },
    recentNotes: {
      title: "Notas Recentes",
      seeRemainingMore: ({ remaining }) => `Ver ${remaining} máis →`,
    },
    transcludes: {
      transcludeOf: ({ targetSlug }) => `Transcluido de ${targetSlug}`,
      linkToOriginal: "Ligazón ao orixinal",
    },
    search: {
      title: "Procurar",
      searchBarPlaceholder: "Procura algo",
    },
    tableOfContents: {
      title: "Táboa de Contidos",
    },
    contentMeta: {
      readingTime: ({ minutes }) => `Lese en ${minutes} min`,
    },
  },
  pages: {
    rss: {
      recentNotes: "Notas recentes",
      lastFewNotes: ({ count }) => `Últimas ${count} notas`,
    },
    error: {
      title: "Non a atopamos.",
      notFound: "Esta páxina é privada ou non existe.",
      home: "Regresa á páxina principal",
    },
    folderContent: {
      folder: "Carpeta",
      itemsUnderFolder: ({ count }) =>
        count === 1 ? "1 artigo nesta carpeta." : `${count} artigos nesta carpeta.`,
    },
    tagContent: {
      tag: "Etiqueta",
      tagIndex: "Índice de Etiquetas",
      itemsUnderTag: ({ count }) =>
        count === 1 ? "1 artigo con esta etiqueta." : `${count} artigos con esta etiqueta.`,
      showingFirst: ({ count }) => `Amosando as primeiras ${count} etiquetas.`,
      totalTags: ({ count }) => `Encontráronse ${count} etiquetas en total.`,
    },
  },
} as const satisfies Translation
