import { Link } from 'react-router-dom';

const copy = {
  privacy: {
    title: 'Privacy Policy',
    updated: 'November 18, 2026',
    body: (
      <>
        <p>Marquee (“we”) is a personal film and TV watch diary. This policy explains what we collect and how we use it.</p>
        <h2 className="mt-6 text-base font-semibold text-ink">Information we collect</h2>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-muted">
          <li>Account details you provide (email, name, password or Google sign-in identifiers).</li>
          <li>Diary data you create (watched titles, episode progress, ratings, favorites, watchlists, imports).</li>
          <li>Technical data needed to run the service (authentication tokens, device tokens if you enable notifications).</li>
        </ul>
        <h2 className="mt-6 text-base font-semibold text-ink">How we use information</h2>
        <p className="mt-2 text-sm text-muted">
          We use your data only to operate Marquee: sign you in, sync your diary across devices, show stats, and improve
          reliability. We do not sell your personal data.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Third parties</h2>
        <p className="mt-2 text-sm text-muted">
          Show and movie metadata and images come from{' '}
          <a className="text-accent underline" href="https://www.themoviedb.org/" target="_blank" rel="noreferrer">
            TMDB
          </a>
          . Sign-in may use Google. Hosting and email providers process data as needed to run the service.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Retention &amp; deletion</h2>
        <p className="mt-2 text-sm text-muted">
          You can delete your account in Marquee (Settings → Delete account). That removes your account and associated
          diary data from our servers.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Contact</h2>
        <p className="mt-2 text-sm text-muted">
          Questions:{' '}
          <a className="text-accent underline" href="mailto:jprajapati2014@gmail.com">
            jprajapati2014@gmail.com
          </a>
        </p>
      </>
    ),
  },
  terms: {
    title: 'Terms of Service',
    updated: 'November 18, 2026',
    body: (
      <>
        <p>By using Marquee you agree to these terms.</p>
        <h2 className="mt-6 text-base font-semibold text-ink">The service</h2>
        <p className="mt-2 text-sm text-muted">
          Marquee is a personal watch diary for films and TV. Features may change as we improve the product.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Your account</h2>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-muted">
          <li>You are responsible for keeping your sign-in credentials secure.</li>
          <li>You must provide accurate information and use the service lawfully.</li>
          <li>You may delete your account at any time from Settings.</li>
        </ul>
        <h2 className="mt-6 text-base font-semibold text-ink">Your content</h2>
        <p className="mt-2 text-sm text-muted">
          You own your diary entries. You grant us permission to store and display them so the app can work for you.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Third-party content</h2>
        <p className="mt-2 text-sm text-muted">
          Titles, artwork, and related metadata are provided by TMDB and other sources. Marquee is not endorsed by TMDB.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Disclaimer</h2>
        <p className="mt-2 text-sm text-muted">
          The service is provided “as is.” We are not liable for indirect or consequential damages arising from use of
          Marquee.
        </p>
        <h2 className="mt-6 text-base font-semibold text-ink">Contact</h2>
        <p className="mt-2 text-sm text-muted">
          <a className="text-accent underline" href="mailto:jprajapati2014@gmail.com">
            jprajapati2014@gmail.com
          </a>
        </p>
      </>
    ),
  },
};

export default function LegalPage({ kind }) {
  const page = copy[kind] || copy.privacy;
  return (
    <div className="mx-auto max-w-2xl px-4 py-10 sm:px-6">
      <p className="text-xs font-semibold uppercase tracking-widest text-muted">
        <Link to="/" className="hover:text-ink">
          Marquee
        </Link>
      </p>
      <h1 className="mt-3 font-serif text-3xl text-ink-bright">{page.title}</h1>
      <p className="mt-1 text-sm text-muted">Last updated: {page.updated}</p>
      <div className="mt-6 space-y-2 text-sm leading-relaxed text-muted">{page.body}</div>
    </div>
  );
}
