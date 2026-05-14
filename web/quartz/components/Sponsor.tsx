import { FullSlug, joinSegments, pathToRoot } from "../util/path"
import { classNames } from "../util/lang"
import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./types"

const Sponsor: QuartzComponent = ({ displayClass, cfg, fileData }: QuartzComponentProps) => {
  const url = new URL(`https://${cfg.baseUrl ?? "example.com"}`)
  const path = url.pathname as FullSlug
  const baseDir = fileData.slug === "404" ? path : pathToRoot(fileData.slug!)
  const imagePath = joinSegments(baseDir, "static/dinahosting-logo.png")

  return (
    <p class={classNames(displayClass, "sponsor")}>
      <a
        href="https://dinahosting.com"
        title="Hosting y alojamiento web en dinahosting"
        target="_blank"
        class="sponsor-link"
      >
        Hosting
      </a>{" "}
      por <img src={imagePath} alt="Dinahosting" class="sponsor-logo" />
    </p>
  )
}

Sponsor.css = `
.sponsor {
  margin-top: 0;
}
.sponsor-link {
  font-weight: normal;
  color: var(--darkgray);
  text-decoration: underline;
}
.sponsor-logo {
  max-width: 100px;
  margin: 0;
  display: inline-block;
  vertical-align: bottom;
  padding-bottom: 3px;
}
`

export default (() => Sponsor) satisfies QuartzComponentConstructor
