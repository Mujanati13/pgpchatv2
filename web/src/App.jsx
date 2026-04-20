function App() {
  return (
    <main className="page-shell" aria-label="PGP Messenger landing page">
      <div className="ambient-grid" aria-hidden="true" />
      <div className="ambient-orb orb-1" aria-hidden="true" />
      <div className="ambient-orb orb-2" aria-hidden="true" />
      <section className="landing-shell">
        <header className="topbar reveal-up" aria-label="Main navigation">
          <div className="brand-pill">
            <img src="/images/ic_launcher_foreground.png" alt="PGP Messenger logo" className="brand-logo" />
            <span>PGP Messenger</span>
          </div>
          <nav className="top-links" aria-label="Primary links">
            <a href="#features">Features</a>
            <a href="#workflow">Workflow</a>
            <a href="#security">Security</a>
            <a href="#download">Download</a>
          </nav>
        </header>

        <section className="hero-grid">
          <div className="hero-copy reveal-up delay-1">
            <p className="eyebrow">Private by default. Trusted by design.</p>
            <h1>Encrypted messaging for teams that protect every word.</h1>
            <p className="subline">
              PGP Messenger gives your organization a calm, modern workspace for confidential conversations.
              Keys stay on device, messages stay encrypted, and trust stays in your hands.
            </p>

            <div className="hero-actions">
              <a className="solid-btn" href="#download">
                Start Secure Chat
              </a>
              <a className="ghost-btn" href="#workflow">
                Watch Product Tour
              </a>
            </div>

            <div className="trust-strip" aria-label="Product highlights">
              <span>Client-side key generation</span>
              <span>Session-bound JWT auth</span>
              <span>Multi-device management</span>
            </div>
          </div>

          <article className="showcase-card reveal-up delay-2" aria-label="Encrypted chat preview">
            <div className="showcase-head">
              <span>Live Secure Thread</span>
              <span>End-to-End Locked</span>
            </div>
            <div className="chat-preview">
              <p className="bubble incoming">Deploy package signed and fingerprint verified.</p>
              <p className="bubble outgoing">Received. Forwarding encrypted summary to ops channel.</p>
              <p className="bubble incoming">Auto-delete policy set to 7 days for incident room.</p>
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

        <section className="metrics reveal-up delay-2" id="security" aria-label="Trust metrics">
          <article>
            <h2>0 private keys</h2>
            <p>ever uploaded to backend servers.</p>
          </article>
          <article>
            <h2>10 MB</h2>
            <p>encrypted payload support for rich media and docs.</p>
          </article>
          <article>
            <h2>Real-time</h2>
            <p>session validation with immediate revocation support.</p>
          </article>
        </section>

        <section className="feature-grid" id="features" aria-label="Feature highlights">
          <article className="feature-card reveal-up delay-1">
            <h3>Message With Confidence</h3>
            <p>
              Compose, encrypt, and send sensitive communication without exposing plain text to transport layers.
            </p>
          </article>
          <article className="feature-card reveal-up delay-2">
            <h3>Control Every Session</h3>
            <p>
              Track active devices, revoke compromised sessions instantly, and keep account security auditable.
            </p>
          </article>
          <article className="feature-card reveal-up delay-3">
            <h3>Respect Data Lifecycles</h3>
            <p>
              Configure auto-delete windows and data retention behavior for safer collaboration in high-risk contexts.
            </p>
          </article>
        </section>

        <section className="workflow reveal-up" id="workflow" aria-label="How it works">
          <div className="workflow-head">
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
            <p className="eyebrow">Get The Mobile App</p>
            <h2>Download PGP Messenger on your preferred device.</h2>
            <p>
              Install on Android from Google Play or on iPhone from the App Store and start secure conversations anywhere.
            </p>
          </div>

          <div className="download-grid">
            <article className="store-card" aria-label="Google Play download">
              <div className="store-icon" aria-hidden="true">
                GP
              </div>
              <div className="store-text">
                <p>Android</p>
                <h3>Google Play</h3>
              </div>
              <a
                className="store-btn"
                href="https://play.google.com/store/apps/details?id=com.yourdomain.pgpchat"
                target="_blank"
                rel="noreferrer"
              >
                Download on Google Play
              </a>
            </article>

            <article className="store-card" aria-label="Apple App Store download">
              <div className="store-icon" aria-hidden="true">
                iOS
              </div>
              <div className="store-text">
                <p>iOS</p>
                <h3>Apple App Store</h3>
              </div>
              <a
                className="store-btn"
                href="https://apps.apple.com/us/app/pgp-messenger/id6761775280"
                target="_blank"
                rel="noreferrer"
              >
                Download on App Store
              </a>
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
