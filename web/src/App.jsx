import { useState } from 'react';

const presentationVideo = new URL('../PGP Chat_ Secure, End-to-End Encrypted Messaging_720p.mp4', import.meta.url).href;

const coinIconMap = {
  BTC: (
    <svg viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <circle cx="32" cy="32" r="30" fill="#F7931A" />
      <path
        d="M37.5 28.2c1.3-.9 2.1-2.2 2.1-4 0-3.9-3.2-5.8-7.6-6.2v-3.4h-3v3.2h-2v-3.2h-3v3.2h-4.1v3h2.3c.7 0 1.1.4 1.2.9v17.4c-.1.5-.5.9-1.2.9h-2.3v3h4.1v3.2h3V43h2v3.2h3v-3.3c5.1-.3 8.6-2.2 8.6-6.7 0-2.8-1.5-4.8-4.1-5.8ZM27 20.7h4.4c2.3 0 4.6.7 4.6 3.2s-2 3.4-4.9 3.4H27v-6.6Zm4.8 18.8H27v-7.2h4.7c3 0 5.4.8 5.4 3.6 0 2.6-2.2 3.6-5.3 3.6Z"
        fill="#fff"
      />
    </svg>
  ),
  ETH: (
    <svg viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <circle cx="32" cy="32" r="30" fill="#627EEA" />
      <path d="M32.2 10 32 10.8v16.1l.2.2 7.5-4.4L32.2 10Z" fill="#fff" fillOpacity="0.9" />
      <path d="m32.2 10-7.5 12.7 7.3 4.4V10Z" fill="#fff" fillOpacity="0.7" />
      <path d="M32.2 36.2 32 36.5v11.5l.2.6 7.5-10.5-7.5-1.9Z" fill="#fff" fillOpacity="0.9" />
      <path d="m32.2 48.6-.2-.6V36.5l-7.3 1.9 7.5 10.2Z" fill="#fff" fillOpacity="0.7" />
      <path d="m32 34.8 7.5-4.3-7.5-3.5v7.8Z" fill="#fff" fillOpacity="0.8" />
      <path d="M24.7 30.5 32 34.8V27l-7.3 3.5Z" fill="#fff" fillOpacity="0.6" />
    </svg>
  ),
  XMR: (
    <svg viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <circle cx="32" cy="32" r="30" fill="#FF6600" />
      <path d="M10 32a22 22 0 0 1 44 0v14H42V32l-10 10-10-10v14H10V32Z" fill="#fff" />
      <path d="M10 46h44a22 22 0 0 1-44 0Z" fill="#4B4B4B" />
    </svg>
  ),
};

function App() {
  const [copiedCoin, setCopiedCoin] = useState('');

  const donationWallets = [
    {
      coin: 'BTC',
      network: 'Bitcoin',
      address: '152v4jx4GZK4nB12nMa5zYqtReTPSygToN',
    },
    {
      coin: 'ETH',
      network: 'Ethereum',
      address: '0x5549E5b98c140E63942c57f004f216a0f37f348f',
    },
    {
      coin: 'XMR',
      network: 'Monero',
      address: '49aSAb7T4Kq7AFL4g1sPFUTE2p8w2wJiUek3LBigtfKJA6zJGBt8yJ1UrZGbygDGjq83muWZBb9F4amAimivPMDZLoHFW12',
    },
  ];

  const handleCopy = async (coin, address) => {
    try {
      await navigator.clipboard.writeText(address);
      setCopiedCoin(coin);
      window.setTimeout(() => setCopiedCoin(''), 1400);
    } catch {
      setCopiedCoin('');
    }
  };

  return (
    <main className="page-shell" aria-label="PGP Messenger landing page">
      <div className="ambient-grid" aria-hidden="true" />
      <div className="ambient-orb orb-1" aria-hidden="true" />
      <div className="ambient-orb orb-2" aria-hidden="true" />
      <section className="landing-shell">
        <header className="topbar reveal-up" aria-label="Main navigation">
          <div className="brand-pill">
            <img src="/images/ic_launcher_foreground.png" alt="PGP Messenger logo" className="brand-logo" loading="eager" decoding="async" />
            <span>PGP Messenger</span>
          </div>
          <nav className="top-links" aria-label="Primary links">
            <a href="#security">Security</a>
            <a href="#features">Features</a>
            <a href="#workflow">Workflow</a>
            <a href="#download">Download</a>
            <a href="#donate">Donate</a>
            <a href="#contact">Contact</a>
          </nav>
        </header>

        <section className="hero-grid">
          <div className="hero-copy reveal-up delay-1">
            <p className="eyebrow">Secure Team Communication</p>
            <h1>PGP Messenger keeps private conversations private.</h1>
            <p className="subline">
              Give your team a focused messaging space where encryption is built-in from the first message.
              Keys stay on-device, sessions are controlled, and sensitive discussions stay protected.
            </p>

            <div className="hero-actions">
              <a className="solid-btn" href="#download">
                Download Mobile App
              </a>
              <a className="ghost-btn" href="#security">
                Review Security Model
              </a>
            </div>

            <div className="trust-strip" aria-label="Product highlights">
              <span>On-device key generation</span>
              <span>Session-bound authentication</span>
              <span>Per-device session control</span>
            </div>

            <ul className="hero-checklist" aria-label="Core value points">
              <li>No private keys sent to the backend</li>
              <li>Identity verification before trust</li>
              <li>Configurable message retention and auto-delete</li>
            </ul>
          </div>

          <article className="showcase-card reveal-up delay-2" aria-label="Presentation video preview">
            <div className="showcase-head">
              <span>Presentation Video</span>
              <span>PGP Chat Overview</span>
            </div>
            <div className="video-frame">
              <video className="presentation-video" controls preload="metadata" playsInline>
                <source src={presentationVideo} type="video/mp4" />
                Your browser does not support the video tag.
              </video>
            </div>
            <div className="showcase-caption">
              <p>PGP Chat_ Secure, End-to-End Encrypted Messaging_720p</p>
              <span>Use the controls to play, pause, or scrub through the presentation.</span>
            </div>
            <div className="showcase-foot" aria-label="Encryption indicators">
              <div>
                <span className="label">Cipher</span>
                <span className="value">AES-256 + RSA-4096</span>
              </div>
              <div>
                <span className="label">Fingerprint</span>
                <span className="value">Verified Chain</span>
              </div>
            </div>
          </article>
        </section>

        <section className="quick-nav reveal-up delay-2" aria-label="Jump to key sections">
          <a className="quick-nav-link" href="#security">
            <span className="quick-nav-index">01</span>
            <span className="quick-nav-label">Security</span>
          </a>
          <a className="quick-nav-link" href="#features">
            <span className="quick-nav-index">02</span>
            <span className="quick-nav-label">Features</span>
          </a>
          <a className="quick-nav-link" href="#workflow">
            <span className="quick-nav-index">03</span>
            <span className="quick-nav-label">Workflow</span>
          </a>
          <a className="quick-nav-link" href="#download">
            <span className="quick-nav-index">04</span>
            <span className="quick-nav-label">Download</span>
          </a>
          <a className="quick-nav-link" href="#donate">
            <span className="quick-nav-index">05</span>
            <span className="quick-nav-label">Donate</span>
          </a>
          <a className="quick-nav-link" href="#contact">
            <span className="quick-nav-index">06</span>
            <span className="quick-nav-label">Contact</span>
          </a>
        </section>

        <section className="metrics-wrap reveal-up delay-2" id="security" aria-label="Security overview">
          <div className="section-head">
            <p className="section-index">01</p>
            <p className="eyebrow">Security Overview</p>
            <h2>Clear controls for high-trust communication</h2>
            <p>Understand exactly where keys are stored, how sessions are validated, and how long data lives.</p>
          </div>

          <div className="metrics">
            <article>
              <p className="metric-tag">Private key handling</p>
              <h3>Device-only storage</h3>
              <p>Private keys are generated and kept locally on each user device.</p>
            </article>
            <article>
              <p className="metric-tag">Encrypted payloads</p>
              <h3>Up to 10 MB</h3>
              <p>Share documents and media while preserving encrypted transport.</p>
            </article>
            <article>
              <p className="metric-tag">Session governance</p>
              <h3>Immediate revocation</h3>
              <p>Invalidate active sessions instantly when a device is lost or compromised.</p>
            </article>
          </div>
        </section>

        <section className="feature-section" id="features" aria-label="Feature highlights">
          <div className="section-head reveal-up delay-1">
            <p className="section-index">02</p>
            <p className="eyebrow">Feature Highlights</p>
            <h2>Everything needed for secure team messaging</h2>
            <p>Designed to keep sensitive communication practical, auditable, and easy to manage.</p>
          </div>

          <div className="feature-grid">
            <article className="feature-card reveal-up delay-1">
              <h3>Encrypt Before Sending</h3>
              <p>Compose and encrypt messages on the client so plaintext is never exposed in transit.</p>
            </article>
            <article className="feature-card reveal-up delay-2">
              <h3>Manage Active Devices</h3>
              <p>View and revoke sessions from one place to reduce risk from stale or unknown logins.</p>
            </article>
            <article className="feature-card reveal-up delay-3">
              <h3>Set Message Lifetimes</h3>
              <p>Apply auto-delete windows that match your compliance and operational policies.</p>
            </article>
          </div>
        </section>

        <section className="workflow reveal-up" id="workflow" aria-label="How it works">
          <div className="workflow-head section-head">
            <p className="section-index">03</p>
            <p className="eyebrow">Simple Secure Flow</p>
            <h2>How PGP Messenger Works</h2>
            <p>
              From key creation to message delivery, each step is designed to keep control on the user device and
              confidentiality intact.
            </p>
          </div>

          <ol className="workflow-steps">
            <li className="workflow-step">
              <div className="step-badge">01</div>
              <p className="step-tag">Key Setup</p>
              <h3>Generate local keys</h3>
              <span>Your device creates and stores private keys. Public keys sync for contact trust.</span>
            </li>
            <li className="workflow-step">
              <div className="step-badge">02</div>
              <p className="step-tag">Identity Trust</p>
              <h3>Verify identity fingerprints</h3>
              <span>Each participant confirms authenticity before sensitive messages are exchanged.</span>
            </li>
            <li className="workflow-step">
              <div className="step-badge">03</div>
              <p className="step-tag">Protected Messaging</p>
              <h3>Encrypt every conversation</h3>
              <span>Messages are sealed at source and only readable by intended recipients.</span>
            </li>
          </ol>
        </section>

        <section className="download-section reveal-up delay-3" id="download" aria-label="Download the app">
          <div className="download-copy">
            <p className="section-index">04</p>
            <p className="eyebrow">Get The Mobile App</p>
            <h2>First 11,111 downloads are free.</h2>
            <p>
              Install on Android or iOS and keep the same secure workflow across your devices.
            </p>
            <p className="pricing-note">After the free limit, Google Play price is USD 0.99 one-time for a lifetime account.</p>
          </div>

          <div className="download-grid">
            <article className="store-card" aria-label="Google Play download">
              <div className="store-icon" aria-hidden="true">
                <img src="/images/ic_launcher_foreground.png" alt="" className="store-icon-logo" loading="lazy" decoding="async" />
              </div>
              <div className="store-text">
                <p>Android</p>
                <h3>Google Play</h3>
                <span className="store-offer">First 11,111 downloads: Free</span>
                <span className="store-price">Then USD 0.99 one-time (lifetime account)</span>
              </div>
              <a
                className="store-btn"
                href="https://play.google.com/store/apps/details?id=com.yourdomain.pgpchat"
                target="_blank"
                rel="noopener noreferrer"
              >
                Download on Google Play
              </a>
            </article>

            <article className="store-card" aria-label="Apple App Store download">
              <div className="store-icon" aria-hidden="true">
                <img src="/images/ic_launcher_foreground.png" alt="" className="store-icon-logo" loading="lazy" decoding="async" />
              </div>
              <div className="store-text">
                <p>iOS</p>
                <h3>Apple App Store</h3>
              </div>
              <a
                className="store-btn"
                href="https://apps.apple.com/us/app/pgp-messenger/id6761775280"
                target="_blank"
                rel="noopener noreferrer"
              >
                Download on App Store
              </a>
            </article>
          </div>
        </section>

        <section className="donate-section reveal-up" id="donate" aria-label="Donate with cryptocurrency">
          <div className="donate-head">
            <p className="section-index">05</p>
            <p className="eyebrow">Support The Project</p>
            <h2>Donate with BTC, ETH, or XMR</h2>
            <p>If PGP Messenger helps you, you can support development with crypto donations.</p>
          </div>

          <div className="wallet-grid">
            {donationWallets.map((wallet) => (
              <article className="wallet-card" key={wallet.coin} aria-label={`${wallet.coin} donation wallet`}>
                <div className="wallet-top">
                  <span className="wallet-brand">
                    <span className="wallet-icon">{coinIconMap[wallet.coin]}</span>
                    <span className="wallet-coin-code">{wallet.coin}</span>
                  </span>
                  <p>{wallet.network}</p>
                </div>
                <code className="wallet-address">{wallet.address}</code>
                <button
                  type="button"
                  className={`wallet-copy ${copiedCoin === wallet.coin ? 'copied' : ''}`}
                  onClick={() => handleCopy(wallet.coin, wallet.address)}
                >
                  {copiedCoin === wallet.coin ? 'Copied' : `Copy ${wallet.coin} Address`}
                </button>
              </article>
            ))}
          </div>
        </section>

        <section className="contact-section reveal-up" id="contact" aria-label="Contact options">
          <div className="contact-head">
            <p className="section-index">06</p>
            <p className="eyebrow">Get In Touch</p>
            <h2>Contact The PGP Messenger Team</h2>
            <p>For help with setup, account issues, or onboarding, reach us directly.</p>
          </div>

          <div className="contact-grid">
            <article className="contact-card" aria-label="General support contact">
              <h3>General Support</h3>
              <p>For setup help, account issues, or onboarding assistance.</p>
              <a className="contact-link" href="mailto:support@pgpchat.app">support@pgpchat.app</a>
            </article>
          </div>
        </section>

        <footer className="landing-foot" aria-label="Footer details">
          <p>PGP Messenger</p>
          <p>Encrypted Collaboration Platform</p>
          <p>2026</p>
        </footer>
      </section>
    </main>
  );
}

export default App;
