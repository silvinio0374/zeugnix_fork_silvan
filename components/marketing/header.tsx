"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Logo } from "@/components/ui/logo";

const nav = [
  { href: "/how-it-works", label: "So funktioniert's" },
  { href: "/verify", label: "Prüfen" },
  { href: "/pricing", label: "Preise" },
  { href: "/for-employers", label: "Für Arbeitgeber" },
];

export function Header() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  // Menü beim Seitenwechsel automatisch schliessen (Klick auf einen Link
  // navigiert, ohne dass die Komponente neu gemountet wird).
  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  return (
    <header className="sticky top-0 z-50 border-b border-ink-200/80 bg-white/85 backdrop-blur-md">
      <div className="container-zx flex h-16 items-center justify-between">
        <Link
          href="/"
          className="flex items-center gap-2.5"
          aria-label="zeugnix.ch Startseite"
        >
          <Logo className="h-7 w-7" />
          <span className="text-[17px] font-medium tracking-tight">
            zeugnix
            <span className="text-petrol-600">.ch</span>
          </span>
        </Link>

        <nav className="hidden items-center gap-8 md:flex">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="text-[13.5px] font-medium text-ink-700 transition-colors hover:text-petrol-700"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <Link
            href="/login"
            className="hidden text-[13.5px] font-medium text-ink-700 transition-colors hover:text-petrol-700 sm:inline-block"
          >
            Anmelden
          </Link>
          <Link
            href="/app/certificates/new"
            className="btn-primary hidden px-4 py-2.5 text-[13px] md:inline-flex"
          >
            Kostenlos starten
          </Link>
          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-label={open ? "Menü schliessen" : "Menü öffnen"}
            aria-expanded={open}
            aria-controls="mobile-nav"
            className="inline-flex h-9 w-9 items-center justify-center rounded-md text-ink-700 hover:bg-ink-50 md:hidden"
          >
            {open ? (
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            ) : (
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <line x1="3" y1="6" x2="21" y2="6" />
                <line x1="3" y1="12" x2="21" y2="12" />
                <line x1="3" y1="18" x2="21" y2="18" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {open && (
        <nav
          id="mobile-nav"
          className="border-t border-ink-200/80 bg-white px-5 py-4 md:hidden"
        >
          <ul className="space-y-1">
            {nav.map((item) => (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className="block rounded-md px-2 py-2.5 text-[14.5px] font-medium text-ink-700 hover:bg-ink-50 hover:text-petrol-700"
                >
                  {item.label}
                </Link>
              </li>
            ))}
            <li>
              <Link
                href="/login"
                className="block rounded-md px-2 py-2.5 text-[14.5px] font-medium text-ink-700 hover:bg-ink-50 hover:text-petrol-700"
              >
                Anmelden
              </Link>
            </li>
          </ul>
          <Link
            href="/app/certificates/new"
            className="btn-primary mt-3 flex w-full items-center justify-center px-4 py-2.5 text-[13px]"
          >
            Kostenlos starten
          </Link>
        </nav>
      )}
    </header>
  );
}
