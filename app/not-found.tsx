import Link from "next/link";

export const metadata = { title: "Seite nicht gefunden" };

export default function NotFound() {
  return (
    <section className="bg-white">
      <div className="container-zx flex min-h-[calc(100vh-4rem)] max-w-md flex-col items-center justify-center py-16 text-center">
        <div className="eyebrow">Fehler 404</div>
        <h1 className="headline-display mt-3 text-[32px] leading-[1.15]">
          Seite nicht gefunden
        </h1>
        <p className="mt-4 text-[14px] leading-relaxed text-ink-600">
          Die aufgerufene Seite existiert nicht oder wurde verschoben.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link href="/" className="btn-primary">
            Zur Startseite
          </Link>
          <Link href="/verify" className="btn-secondary">
            Zeugnis prüfen
          </Link>
        </div>
      </div>
    </section>
  );
}
