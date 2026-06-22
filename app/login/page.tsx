import { LoginForm } from "@/components/forms/login-form";
import { Logo } from "@/components/ui/logo";
import Link from "next/link";

export const metadata = {
  title: "Anmelden",
  description: "Anmelden bei zeugnix.ch via Magic Link",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <section className="bg-white">
      <div className="container-zx flex min-h-[calc(100vh-4rem)] max-w-md flex-col justify-center py-16">
        <div className="text-center">
          <Link href="/" className="inline-flex items-center gap-2.5">
            <Logo className="h-8 w-8" />
            <span className="text-[18px] font-medium tracking-tight">
              zeugnix
              <span className="text-petrol-600">.ch</span>
            </span>
          </Link>
        </div>

        <h1 className="headline-display mt-12 text-center text-[28px] leading-tight">
          Anmelden
        </h1>
        <p className="mt-3 text-center text-[14px] text-ink-600">
          Wir senden Ihnen einen Magic Link an Ihre E-Mail-Adresse.
          <br />
          Kein Passwort nötig.
        </p>

        {error && (
          <div className="mt-6 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-center text-[12.5px] text-red-700">
            Anmeldung über den Link fehlgeschlagen: {error}
          </div>
        )}

        <div className="mt-10">
          <LoginForm />
        </div>

        <p className="mt-8 text-center text-[12px] text-ink-500">
          Mit der Anmeldung stimmen Sie unseren{" "}
          <Link href="/legal/terms" className="underline">
            AGB
          </Link>{" "}
          und der{" "}
          <Link href="/legal/privacy" className="underline">
            Datenschutzerklärung
          </Link>{" "}
          zu.
        </p>
      </div>
    </section>
  );
}
