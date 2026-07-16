import type { ReactNode } from "react";

interface LegalSection {
  heading: string;
  body: ReactNode;
}

interface LegalContentProps {
  title: string;
  updated: string;
  intro?: ReactNode;
  sections: LegalSection[];
}

/** Markiert einen noch zu ersetzenden Betreiber-Angaben-Platzhalter sichtbar. */
export function Placeholder({ children }: { children: ReactNode }) {
  return (
    <span className="rounded bg-amber-50 px-1 py-0.5 font-medium text-amber-800 ring-1 ring-inset ring-amber-200">
      {children}
    </span>
  );
}

export function LegalContent({ title, updated, intro, sections }: LegalContentProps) {
  return (
    <section className="bg-white py-24">
      <div className="container-zx max-w-3xl">
        <div className="eyebrow">Rechtliches</div>
        <h1 className="headline-display mt-3 text-[40px] leading-[1.1]">
          {title}
        </h1>
        <p className="mt-3 text-[12.5px] text-ink-500">
          Stand: {updated}
        </p>
        {intro && (
          <p className="mt-6 text-[15px] leading-relaxed text-ink-600">
            {intro}
          </p>
        )}

        <div className="mt-10 space-y-9">
          {sections.map((section) => (
            <div key={section.heading}>
              <h2 className="text-[17px] font-medium tracking-tight text-ink-900">
                {section.heading}
              </h2>
              <div className="mt-2.5 space-y-3 text-[14.5px] leading-relaxed text-ink-600">
                {section.body}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
